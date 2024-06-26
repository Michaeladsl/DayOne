#!/bin/bash

# Creator: Michael Raines
CURRENT_VERSION="1.10"
REPO_URL="https://raw.githubusercontent.com/Michaeladsl/DayOne/main/DayOne.sh"

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DAY_ONE_SCANS_DIR="$SCRIPT_DIR/DayOneScans"
TOOLS_DIR="$DAY_ONE_SCANS_DIR/tools"

check_version() {
    LATEST_VERSION=$(curl -s "$REPO_URL" | grep -E '^CURRENT_VERSION="' | cut -d '"' -f 2)
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        echo "Your script is outdated. Your version is ${RED}$CURRENT_VERSION${NC}, latest version is $LATEST_VERSION."
        echo "Please consider updating for new features and fixes."
    fi
}


regions_flag=false
DISABLED_TOOLS=""
surpress_updates=false
list_tools_flag=false
verbose_mode=false
new_tool_downloaded=0

# Color definitions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2; tput bold)
ORANGE=$(tput setaf 3)
YELLOW=$(tput setaf 3; tput bold)
CYAN=$(tput setaf 6)
NC=$(tput sgr0) # No Color

while getopts "D:rthvsk" flag; do
    case "$flag" in
        D) DISABLED_TOOLS="$OPTARG" ;;
        r) regions_flag=true ;;
        k) IFS=',' read -ra additional_keywords <<< "$OPTARG" ;;
	s) surpress_updates=true ;;
        t) echo "Available tools that can be disabled with -D:"
           echo " 1. pymeta"
           echo " 2. cloudenum"
           echo " 3. crosslinked"
           echo " 4. dehashed"
           echo " 5. dnscan"
           echo " 6. subfinder"
           echo " 7. crt.sh"
           echo " 8. subjack"
           echo " 9. dnstwist"
           echo " 10. DNSMap"
           echo " 11. registereddomains"
           echo " 12. AADUserEnum"
           echo " 13. onedrive_enum"
           echo " 14. comma-separated: pymeta,cloudenum,crosslinked,dehashed,dnscan,subfinder,crt.sh,subjack,dnstwist,DNSMap,registereddomains,AADUserEnum,onedrive_enum"
           exit 0 ;;
        h) echo "Usage: $0 [-D <tool_name>] [-r] [-t] [-v] [-s] [-h]"
           echo " -D <tool_name> : Disable a specific tool (e.g., pymeta, cloudenum)"
           echo " -r             : Enable all regions in cloud_enum (slow)"
           echo " -t             : List all available tools that can be disabled"
           echo " -s             : Surpress updates and dependencies"
           echo " -h             : Show this help message"
           echo " -v             : Verbose Mode (for error checking)"
           exit 0 ;;
        *) echo "Usage: $0 [-D <tool_name>] [-r] [-t] [-v] [-s] [-h] $flag"
           echo "$flag"
           exit 1 ;;
    esac
done


# Convert the comma-separated list into an array
IFS=',' read -ra DISABLED_ARRAY <<< "$DISABLED_TOOLS"

shift $((OPTIND-1))

is_tool_disabled() {
    local tool="$1"
    for disabled_tool in "${DISABLED_ARRAY[@]}"; do
        if [[ "$disabled_tool" == "$tool" ]]; then
            return 0
        fi
    done
    return 1
}

if [ "$verbose_mode" = true ]; then
    set -x
fi


# URLs for each tool
declare -A tool_urls=(
    ["CrossLinked"]="https://github.com/m8sec/CrossLinked.git"
    ["dnscan"]="https://github.com/rbsec/dnscan.git"
    ["cloud_enum"]="https://github.com/initstring/cloud_enum.git"
    ["onedrive_user_enum"]="https://github.com/nyxgeek/onedrive_user_enum.git"
    ["subfinder"]="https://github.com/projectdiscovery/subfinder.git"
    ["crt.sh"]="https://github.com/az7rb/crt.sh.git"
)

# Function to clone a repository with retries
clone_repo_with_retries() {
    local repo_url="$1"
    local repo_dir="$2"
    local max_retries=3
    local retry_delay=5
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        echo "Attempting to clone $repo_url into $repo_dir (Attempt $attempt/$max_retries)..."
        git clone "$repo_url" "$repo_dir" && {
            echo "Successfully cloned $repo_url into $repo_dir"
            return 0
        } || {
            echo "Failed to clone $repo_url, retrying in $retry_delay seconds..."
            sleep $retry_delay
        }
        ((attempt++))
    done
    echo "Failed to clone $repo_url into $repo_dir after $max_retries attempts."
    return 1
}

clone_repo_if_missing() {
    local repo_name="$1"
    local repo_url="${tool_urls[$repo_name]}"
    local repo_dir="$DAY_ONE_SCANS_DIR/tools/$repo_name"
    
    if [ ! -d "$repo_dir" ]; then
        echo "Cloning $repo_name from $repo_url..."
        clone_repo_with_retries "$repo_url" "$repo_dir"
    else
        echo "$repo_name already exists."
    fi
}

mkdir -p "$TOOLS_DIR"

echo "Cloning required repositories..."
for tool in "${!tool_urls[@]}"; do
    clone_repo_if_missing "$tool"
done

sudo apt update && sudo apt install golang -y > /dev/null 2>&1
pip3 install mysql.connector

SUBFINDER_DIR="$TOOLS_DIR/subfinder/v2/cmd/subfinder"
if [ -d "$SUBFINDER_DIR" ]; then
    (cd "$SUBFINDER_DIR" && go build . && sudo mv subfinder /usr/local/bin/)
fi

sudo pip3 install pymetasec > /dev/null 2>&1


# Ensure the tools directory exists
if [ -d "$TOOLS_DIR" ]; then
    cd "$TOOLS_DIR"

    clone_repo_if_missing "crt.sh"
    clone_repo_if_missing "dnscan"
    clone_repo_if_missing "cloud_enum"

else
    echo "$TOOLS_DIR does not exist."
fi

if [ $new_tool_downloaded -eq 1 ]; then
    cd "$TOOLS_DIR"
    echo "" > combined_requirements.txt
    
    # Loop through all directories in the current folder ($TOOLS_DIR)
    for dir in ./*; do
        if [ -d "$dir" ]; then
            # If the directory contains a requirements.txt, append it to the combined file
            if [ -f "$dir/requirements.txt" ]; then
                cat "$dir/requirements.txt" >> combined_requirements.txt
                echo "" >> combined_requirements.txt
            fi
        fi
    done
    
    # Remove duplicate entries from combined_requirements.txt
    sort combined_requirements.txt | uniq > temp_requirements.txt
    mv temp_requirements.txt combined_requirements.txt
    
    # Install required Python packages
    pip3 install -r combined_requirements.txt
fi

if [ "$regions_flag" = true ]; then
    azure_regions_file="$TOOLS_DIR/cloud_enum/enum_tools/azure_regions.py"
    gcp_regions_file="$TOOLS_DIR/cloud_enum/enum_tools/gcp_regions.py"

    cp "$azure_regions_file" "${azure_regions_file}.backup"
    cp "$gcp_regions_file" "${gcp_regions_file}.backup"

    sed -i '$d; $d; $d; $d' "$azure_regions_file"
    sed -i '$d; $d; $d; $d' "$gcp_regions_file"
fi

if [ "$surpress_updates" = false ]; then
    echo "Updating and installing necessary packages..."
    sudo apt update > /dev/null 2>&1
    sudo apt install -y urlcrazy exiftool figlet dnstwist subjack dnsrecon jq > /dev/null 2>&1

    # Install tool dependencies using pip
    echo "Installing tool dependencies..."
    pip3 install -r "$TOOLS_DIR/requirements.txt" > /dev/null 2>&1
    pip3 install -r "$TOOLS_DIR/cloud_enum/requirements.txt" > /dev/null 2>&1

    # Install Pymeta and fix errors
    sudo pip3 install pymetasec > /dev/null 2>&1
    sleep 5
fi

error_output=$(pymeta 2>&1)

file_path=$(echo "$error_output" | grep -o 'File ".*__init__.py"' | awk -F'"' '{print $2}')

# Check if file_path starts with /.local and prepend ~ if it does
if [[ "$file_path" == /.local* ]]; then
    file_path="~$file_path"
fi

if [[ -n "$file_path" ]]; then
    # Modify the problematic file
    sudo sed -i '140s/^[[:space:]]*//' "$file_path"
else
    echo " "
fi

TMUX_CONF_PATH=$(sudo find / -type f \( -name ".tmux.conf" -o -name "tmux.conf" \) 2>/dev/null | head -n 1)

# Check if the file was found.
if [[ ! -z "$TMUX_CONF_PATH" ]]; then
    if ! sudo grep -q "@retain-ansi-escapes" "$TMUX_CONF_PATH"; then
        echo "Appending configuration to tmux"

        
        # Append the required line with elevated privileges.
        echo "set -g @retain-ansi-escapes true" | sudo tee -a "$TMUX_CONF_PATH" > /dev/null
        tmux source-file $TMUX_CONF_PATH
    fi

fi

echo " "
echo " "
echo " "
echo "${CYAN}██████╗  █████╗ ██╗   ██╗ ██████╗ ███╗   ██╗███████╗";
echo "██╔══██╗██╔══██╗╚██╗ ██╔╝██╔═══██╗████╗  ██║██╔════╝";
echo "██║  ██║███████║ ╚████╔╝ ██║   ██║██╔██╗ ██║█████╗  ";
echo "██║  ██║██╔══██║  ╚██╔╝  ██║   ██║██║╚██╗██║██╔══╝  ";
echo "██████╔╝██║  ██║   ██║   ╚██████╔╝██║ ╚████║███████╗";
echo "╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝";
echo "                                                    ${NC}";
echo " "
echo " "
echo " "
check_version

validate_domain() {
    if [[ ! $1 =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "${RED}Invalid domain format. Please enter a valid domain.${NC}"
        return 1
    fi
    return 0
}

process_and_clean_files() {
    local domain_dir="$DAY_ONE_SCANS_DIR/$1"
    tr '[:upper:]' '[:lower:]' < "$domain_dir/emails.txt" > "$domain_dir/emails_lower.txt"
    mv "$domain_dir/emails_lower.txt" "$domain_dir/emails.txt"
    sort -u "$domain_dir/emails.txt" -o "$domain_dir/emails.txt"
    cat "$domain_dir/emails.txt" | sed -e "s/@$1//g" -e "s/www\.//g" | sort -u > "$domain_dir/usernames.txt"
    sort -u "$domain_dir/usernames.txt" -o "$domain_dir/usernames.txt"
}

validate_domain() {
    if [[ ! $1 =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "${RED}Invalid domain format. Please enter a valid domain.${NC}"
        return 1
    fi
    return 0
}

while true; do
    read -p "${ORANGE}Enter the domain (domain.com): ${NC}" domain
    if validate_domain "$domain"; then
        break
    fi
done

echo -e "\nCreating directory for domain: $domain"
mkdir -p "$DAY_ONE_SCANS_DIR/$domain" || { echo "${RED}Failed to create directory. Exiting.${NC}"; exit 1; }

echo " "
echo " "


if ! is_tool_disabled "crosslinked"; then

    echo " ${ORANGE}=========== Choose a format for {f}{last}: ===========${NC}"
    echo " 1. {f}{last}"
    echo " 2. {first}.{last}"
    echo " 3. {first}{last}"
    echo " 4. {first}{l}"
    echo " 5. {first}"
    echo " 6. {last}{f}"
    echo " "
    echo " "
    read -p "${ORANGE}Enter the option (1/2/3/4/5): ${NC}" format_option
    echo " "
    echo " "

    case $format_option in
        1) format="{f}{last}" ;;
        2) format="{first}.{last}" ;;
        3) format="{first}{last}" ;;
        4) format="{first}{l}" ;;
        5) format="{first}" ;;
        6) format="{last}{f}" ;;
        *) echo "Invalid option. Using default format {f}{last}"; format="{f}{last}" ;;
    esac

    # Construct the email format
    email_format="${format}@${domain}"
    echo " "
    echo " "

    read -p "${ORANGE}Enter the organization name as it appears on${NC} ${RED}LinkedIn${NC} ${ORANGE}or re-enter the domain:${NC} " org_name
    echo " "
    echo " "
fi

read -p "${ORANGE}Do you want to attempt the Microsoft Direct Send vulnerability?${NC} (${GREEN}YES${NC}/${RED}NO${NC}): " direct_send
echo " "
echo " "
direct_send=$(echo "$direct_send" | tr '[:upper:]' '[:lower:]')

if [ "$direct_send" == "yes" ]; then
    read -p "${ORANGE}Enter your targets email typically (POC): ${NC}" poc_email
    echo " "
    echo " "
    read -p "${ORANGE}Enter your email: ${NC}" employee_email
fi

echo " "
echo " "
echo " "
echo " "
AADUserEnum=$(echo "$AADUserEnum" | tr '[:upper:]' '[:lower:]')
read -p "${ORANGE}Do you have permission to test cloud environments (AADUserEnum)?${NC}(${GREEN}YES${NC}/${RED}NO${NC})${YELLOW}:${NC} " permission
echo " "
echo " "
echo " "
echo " "
echo "${GREEN}=========== Inputing Data ===========${NC}"
tmux new-session -d -s aadint_session1 'pwsh'
tmux send-keys -t aadint_session1 "Install-Module AADInternals" C-m
sleep 8
tmux send-keys -t aadint_session1 "A" C-m
sleep 5
tmux send-keys -t aadint_session1 "Import-Module AADInternals" C-m
##################################################################
##################################################################
echo "Complete"



# Run pymeta.py
if ! is_tool_disabled "pymeta"; then
    echo " "
    echo "${GREEN}========== Running Pymeta ==========${NC}"
    echo " "
    pymeta -j 7 -d "$domain" -f "$DAY_ONE_SCANS_DIR/$domain/metadata.csv" -s all
fi

# Run crosslinked.py
if ! is_tool_disabled "crosslinked"; then
    echo " "
    echo "${GREEN}========== Running Crosslinked ==========${NC}"
    echo " "
    python3 "$DAY_ONE_SCANS_DIR/tools/CrossLinked/crosslinked.py" -j 7 -f "${format}@${domain}" "$org_name" -o "$DAY_ONE_SCANS_DIR/$domain/emails"

    echo " "
    echo "Processing and cleaning up emails.txt..."
    cat "$DAY_ONE_SCANS_DIR/$domain/emails.txt" | tr '[:upper:]' '[:lower:]' | sort -u > "$DAY_ONE_SCANS_DIR/$domain/emails_tmp.txt"
    mv "$DAY_ONE_SCANS_DIR/$domain/emails_tmp.txt" "$DAY_ONE_SCANS_DIR/$domain/emails.txt"
    cat "$DAY_ONE_SCANS_DIR/$domain/emails.txt" | sed "s/@$domain//g" | sort -u > "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
fi
echo " "
echo " "
echo " "

# Run dehashed.py if it exists
if ! is_tool_disabled "dehashed"; then
    if [ -f "$DAY_ONE_SCANS_DIR/tools/dehashed.py" ]; then
        echo " "
        echo "${GREEN}========== Running Dehashed ==========${NC}"
        python3 "$DAY_ONE_SCANS_DIR/tools/dehashed.py" -d "$domain" -o "$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv"
    else
        echo " "
        find ~/ -name "dehashed.py" -exec cp {} "$DAY_ONE_SCANS_DIR/tools/dehashed.py" \; 2>/dev/null;
        if [ -f "$DAY_ONE_SCANS_DIR/tools/dehashed.py" ]; then
            echo "${GREEN}========== Running Dehashed ==========${NC}"
            python3 "$DAY_ONE_SCANS_DIR/tools/dehashed.py" -d "$domain" -o "$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv"
        else
            echo "${RED}(dehashed.py not found. Moving on to the next script.)${NC}"
        fi
    fi
fi

echo " "

# Extract email addresses from domainBreachData.csv and append to emails.txt
if [ -f "$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv" ]; then
    echo "${YELLOW}Extracting email addresses from domainBreachData.csv...${NC}"
    grep -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}' "$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv" | grep -v "^[0-9]" | sort -u >> "$DAY_ONE_SCANS_DIR/$domain/emails.txt"
    tr '[:upper:]' '[:lower:]' < "$DAY_ONE_SCANS_DIR/$domain/emails.txt" > "$DAY_ONE_SCANS_DIR/$domain/emails_lower.txt"
    mv "$DAY_ONE_SCANS_DIR/$domain/emails_lower.txt" "$DAY_ONE_SCANS_DIR/$domain/emails.txt"
    sort -u "$DAY_ONE_SCANS_DIR/$domain/emails.txt" -o "$DAY_ONE_SCANS_DIR/$domain/emails.txt"
    cat "$DAY_ONE_SCANS_DIR/$domain/emails.txt" | sed -e "s/@$domain//g" -e "s/www\.//g" | sort -u > "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
    sort -u "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" -o "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
fi


if [ -f "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" ]; then
    tr '[:upper:]' '[:lower:]' < "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" > "$DAY_ONE_SCANS_DIR/$domain/usernames_lower.txt"
    mv "$DAY_ONE_SCANS_DIR/$domain/usernames_lower.txt" "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
    sort -u "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" -o "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
    sed -e 's/@.*//' -e 's/www\.//' "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" > "$DAY_ONE_SCANS_DIR/$domain/cleaned_usernames.txt"
    mv "$DAY_ONE_SCANS_DIR/$domain/cleaned_usernames.txt" "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
    sort -u "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" -o "$DAY_ONE_SCANS_DIR/$domain/usernames.txt"
fi

if [ -f "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" ]; then
    while read username; do
        echo "${username}@$domain"
    done < "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" >> "$DAY_ONE_SCANS_DIR/$domain/emails.txt"
    sort -u "$DAY_ONE_SCANS_DIR/$domain/emails.txt" -o "$DAY_ONE_SCANS_DIR/$domain/emails.txt"
fi


# Run onedrive_enum.py with user-supplied domain and usernames.txt
if ! is_tool_disabled "onedrive_enum"; then
    echo " "
    echo " "
    echo "${GREEN}========== Finding Valid User Accounts ==========${NC}"
    echo " "
    echo " "
    cd "$TOOLS_DIR/onedrive_user_enum"
    python3 onedrive_enum.py -d "$domain" -U "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" -r
    mv emails* "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt"
    cd - > /dev/null
fi

sort -u "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt" -o "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt"

# Check if permission is granted for AADUserEnum
if [ "$permission" == "yes" ] && ! is_tool_disabled "AADUserEnum"; then
    tmux send-keys -t aadint_session1 "Get-Content $DAY_ONE_SCANS_DIR/$domain/emails.txt | Invoke-AADIntUserEnumerationAsOutsider | Export-Csv -Path $DAY_ONE_SCANS_DIR/$domain/AADuserenum.txt -NoTypeInformation" C-m
    sleep 20
    echo " "
    echo " "
else
    echo " "
    echo " "
    echo "${RED}(Skipping user enumeration, permission was not granted.)${NC}"
fi

# Run cloud_enum.py with specified parameters
if ! is_tool_disabled "cloudenum"; then
    echo "${GREEN}========== Running cloud_enum ==========${NC}"
    keyword_params=""
    for keyword in "${additional_keywords[@]}"; do
        keyword_params+="-k '$keyword' "
    done
    script -c "python3 $TOOLS_DIR/cloud_enum/cloud_enum.py -k '$domain' -k '$cloud_enum_keyword' $keyword_params -t 25 -l '$DAY_ONE_SCANS_DIR/$domain/CloudEnum.Log' | grep -v -e '\[!\] DNS Timeout on' -e '\[!\] Connection error on' -e '^HTTPConnectionPool'" -f "$DAY_ONE_SCANS_DIR/$domain/CloudEnumFULL.txt"
fi

# Process validated emails and usernames
if [ -f "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt" ]; then
    sort -u "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt" -o "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt"
    sed "s/@${domain}//" "$DAY_ONE_SCANS_DIR/$domain/emails_valid.txt" > "$DAY_ONE_SCANS_DIR/$domain/validusers.txt"
fi

if [ -f "$DAY_ONE_SCANS_DIR/$domain/AADuserenum.txt" ]; then
    awk -F',' '$2 ~ /"True"/ { gsub(/"/, "", $1); print $1 }' "$DAY_ONE_SCANS_DIR/$domain/AADuserenum.txt" >> "$DAY_ONE_SCANS_DIR/$domain/validusers.txt"
    awk -F'@' '{print $1}' "$DAY_ONE_SCANS_DIR/$domain/validusers.txt" | sort > "$DAY_ONE_SCANS_DIR/$domain/temp.txt" && mv "$DAY_ONE_SCANS_DIR/$domain/temp.txt" "$DAY_ONE_SCANS_DIR/$domain/validusers.txt"
    sed -i "s/@$domain//g" "$DAY_ONE_SCANS_DIR/$domain/validusers.txt"
    sort -u "$DAY_ONE_SCANS_DIR/$domain/validusers.txt" -o "$DAY_ONE_SCANS_DIR/$domain/validusers.txt"
fi


sleep 5

# Run dnscan.py with specified parameters
if ! is_tool_disabled "dnscan"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Gathering DNS Info ==========${NC}"
    echo " "
    echo " "
    sed -i -E 's/timeout=([0-9]+)/timeout=4/g' "$TOOLS_DIR/dnscan/dnscan.py"
    sed -i -E 's/timeout[ ]*=[ ]*([0-9]+)/timeout = 4/g' "$TOOLS_DIR/dnscan/dnscan.py"
    python3 $TOOLS_DIR/dnscan/dnscan.py -d "$domain" -n -o "$DAY_ONE_SCANS_DIR/$domain/DNSInfo"
    awk -F" - " '/ - / {print $2}' "$DAY_ONE_SCANS_DIR/$domain/DNSInfo" > "$DAY_ONE_SCANS_DIR/$domain/temp_dnsinfo.txt"
    

    dnsrecon -d "$domain" -t std > "$DAY_ONE_SCANS_DIR/$domain/dnsrecon.txt"

    # Check if the file 'dnsrecon.txt' exists and is readable
    if [ -r "$DAY_ONE_SCANS_DIR/$domain/dnsrecon.txt" ]; then
        grep -oP '(MX|A|TXT|SRV|NS|SOA) \K[^ ]*\.com' "$DAY_ONE_SCANS_DIR/$domain/dnsrecon.txt" > "$DAY_ONE_SCANS_DIR/$domain/extracted_dnsrecords.txt"
        sort -u $DAY_ONE_SCANS_DIR/$domain/temp_dnsinfo.txt $DAY_ONE_SCANS_DIR/$domain/extracted_dnsrecords.txt > $DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt
        rm $DAY_ONE_SCANS_DIR/$domain/temp_dnsinfo.txt
        sed -i 's/\x1b\[[0-9;]*m//g' "$DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt"

        grep -E -o "[a-zA-Z0-9.-]+\.$domain" "$DAY_ONE_SCANS_DIR/$domain/DNSInfo" >> "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt"
    fi

fi

smtp_server=$(grep -E -o '[A-Za-z0-9.-]+\.mail\.protection\.outlook\.com' "$DAY_ONE_SCANS_DIR/$domain/DNSInfo" | grep -o -E '[A-Za-z0-9-]+\.mail\.protection\.outlook\.com')


if grep -q -E '[A-Za-z0-9.-]+\.mail\.protection\.outlook\.com' "$DAY_ONE_SCANS_DIR/$domain/DNSInfo"; then
    smtp_server=$(grep -E -o '[A-Za-z0-9.-]+\.mail\.protection\.outlook\.com' "$DAY_ONE_SCANS_DIR/$domain/DNSInfo")
else
    # Replace dots with hyphens for the domain part before the TLD
    formatted_domain=$(echo "$domain" | sed 's/\./-/g')
    smtp_server="${formatted_domain}.mail.protection.outlook.com"
fi

if [ "$direct_send" == "yes" ]; then
    echo "${GREEN}========= Direct Send Vulnerability Test =========${NC}"
    echo " "
    tmux new-session -d -s mail_session 'pwsh'
    sleep 4
    tmux send-keys -t mail_session "Send-MailMessage -SmtpServer $smtp_server -To $poc_email -From test@$domain -Subject 'Test Email' -Body 'This is a test as part of the current round of testing. Please forward this to $employee_email' -BodyAsHTML" C-m
    sleep 10
    tmux capture-pane -t mail_session -e -p > "$DAY_ONE_SCANS_DIR/$domain/DirectSend.txt"
    cat "$DAY_ONE_SCANS_DIR/$domain/DirectSend.txt"
fi



# Run subfinder with specified parameters
if ! is_tool_disabled "subfinder"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Looking for Subdomains ==========${NC}"
    echo " "
    echo " "
    subfinder -d "$domain" -all -oI -active -o "$DAY_ONE_SCANS_DIR/$domain/subfindersubs"
    grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' "$DAY_ONE_SCANS_DIR/$domain/subfindersubs" | sort -u > "$DAY_ONE_SCANS_DIR/$domain/hosts.txt"
fi

if ! is_tool_disabled "crt.sh"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo " "
    echo " "
    cd $TOOLS_DIR/crt.sh
    chmod +x crt.sh
    ./crt.sh -d $domain
    cd -
    mv $TOOLS_DIR/crt.sh/output/domain.$domain.txt $DAY_ONE_SCANS_DIR/$domain/crtsubdomains.txt
fi

cat "$DAY_ONE_SCANS_DIR/$domain/crtsubdomains.txt" >> "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt"

# Extract IPs from DNSInfo and append to hosts.txt
grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' "$DAY_ONE_SCANS_DIR/$domain/DNSInfo" | sort -u >> "$DAY_ONE_SCANS_DIR/$domain/hosts.txt"
grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' "$DAY_ONE_SCANS_DIR/$domain/dnsrecon.txt" | sort -u >> "$DAY_ONE_SCANS_DIR/$domain/hosts.txt"


# Sort and remove duplicates from hosts.txt
sort -u "$DAY_ONE_SCANS_DIR/$domain/hosts.txt" -o "$DAY_ONE_SCANS_DIR/$domain/hosts.txt"

# Remove the IP addresses 8.8.8.8 and 8.8.1.1 from the file
grep -v -e '8\.8\.8\.8' -e '8\.8\.1\.1' "$DAY_ONE_SCANS_DIR/$domain/hosts.txt" > "$DAY_ONE_SCANS_DIR/$domain/temp_hosts.txt"

# Move the temporary file back to the original file
mv "$DAY_ONE_SCANS_DIR/$domain/temp_hosts.txt" "$DAY_ONE_SCANS_DIR/$domain/hosts.txt"


# Extract subdomains and create subdomains.txt
cut -d ',' -f 1 "$DAY_ONE_SCANS_DIR/$domain/subfindersubs" | sort -u >> "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt"

# Sort and remove duplicates from subdomains.txt
sort -u "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt" -o "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt"

# Check Subdomain Takeover
if ! is_tool_disabled "subjack"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Checking For Subdomain Takeover ==========${NC}"
    echo " "
    echo " "
    subjack -w "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt" -t 100 -timeout 30 -o "$DAY_ONE_SCANS_DIR/$domain/subtakeover.txt" -ssl -m -c /usr/share/subjack/fingerprints.json -v 1 >/dev/null 2>&1

    # Display the first 10 lines of subtakeover.txt
    head -n 10 "$DAY_ONE_SCANS_DIR/$domain/subtakeover.txt"

    # Display lines from subtakeover.txt that begin with [Vulnerable]
    grep -v '^\[Not Vulnerable\]' "$DAY_ONE_SCANS_DIR/$domain/subtakeover.txt"
    echo "====================================================="
fi

# Run dnstwist
if ! is_tool_disabled "dnstwist"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}=============== Looking For Squatters ===============${NC}"

    # Run dnstwist
    dnstwist -o $DAY_ONE_SCANS_DIR/$domain/squatting.csv -f csv -t 20 -r "$domain"
    echo " "
    echo "${RED}Squatters found...      ${NC}"
fi

if ! is_tool_disabled "DNSMap"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}============= Downloading DNSMap image =============${NC}"
    echo " "

    # Use -w to write the HTTP status code to a variable, and -o to specify the output file
    http_status=$(curl -w "%{http_code}" -o "$DAY_ONE_SCANS_DIR/$domain/DNSMap.png" "https://dnsdumpster.com/static/map/$domain.png")
    
    # Check if the HTTP status code is 200 (OK)
    if [ "$http_status" -eq 200 ]; then
        echo " "
        echo " "
        echo "${ORANGE}DNSMap image downloaded to $DAY_ONE_SCANS_DIR/$domain/DNSMap.png${NC}"
    else
        echo " "
        echo " "
        echo "${RED}Failed to download DNSMap image. HTTP Status Code: $http_status${NC}"
    fi
fi

if ! is_tool_disabled "registereddomains"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}============ Checking Registered Domains ============${NC}"
    echo " "
    echo " "

    # Launch a background TMUX session with PowerShell
    tmux new-session -d -s aadint_session2 'pwsh' 
    tmux send-keys -t aadint_session2 "Import-Module AADInternals" C-m
    sleep 10
    # Send the PowerShell command to the TMUX session
    tmux send-keys -t aadint_session2 "Get-AADIntTenantDomains -Domain $domain | Out-File -FilePath $DAY_ONE_SCANS_DIR/$domain/registereddomains.txt" C-m

    # Wait for the command to finish
    sleep 20  # You can adjust the sleep time as needed
    tmux kill-session -t aadint_session2

    grep -Eo '[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$DAY_ONE_SCANS_DIR/$domain/registereddomains.txt" > "$DAY_ONE_SCANS_DIR/$domain/extracted_domains.txt"
    mv "$DAY_ONE_SCANS_DIR/$domain/extracted_domains.txt" "$DAY_ONE_SCANS_DIR/$domain/RegisteredDomainsSorted.txt"
    echo " "
    echo " "
    echo "${RED}           Registered Domain Data Captured          ${NC}"
    echo " "
    echo " "
    echo " "
    echo " "
fi
# Kill the TMUX session
tmux kill-session -t aadint_session1


tmux kill-session -t mail_session


# Restoring original files for cloud_enum
if [ "$regions_flag" = true ]; then
    mv "${azure_regions_file}.backup" "$azure_regions_file"
    mv "${gcp_regions_file}.backup" "$gcp_regions_file"
fi

# Counting files contents for display
if [ -r "$DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt" ]; then
    dnsrecords=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt' not found or is not readable."
    dnsrecords=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/hosts.txt" ]; then
    hosts_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/hosts.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/hosts.txt' not found or is not readable."
    hosts_count=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt" ]; then
    subdomains_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/subdomains.txt' not found or is not readable."
    subdomains_count=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/emails.txt" ]; then
    emails_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/emails.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/emails.txt' not found or is not readable."
    emails_count=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" ]; then
    usernames_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/usernames.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/usernames.txt' not found or is not readable."
    usernames_count=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/squatting.csv" ]; then
    squatting_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/squatting.csv")
    if [ "$squatting_count" -gt 0 ]; then
        ((squatting_count--))
    fi
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/squatting.csv' not found or is not readable."
    squatting_count=0
fi


if [ -r "$DAY_ONE_SCANS_DIR/$domain/RegisteredDomainsSorted.txt" ]; then
    registered_domains=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/RegisteredDomainsSorted.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/RegisteredDomainsSorted.txt' not found or is not readable."
    registered_domains=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/validusers.txt" ]; then
    valid_users=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/validusers.txt")
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/validusers.txt' not found or is not readable."
    valid_users=0
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv" ]; then
    breach_data_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv")
    if [ "$breach_data_count" -gt 0 ]; then
        ((breach_data_count--))
    fi
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/${domain}BreachData.csv' not found or is not readable."
    breach_data_count=0
fi


if [ -r "$DAY_ONE_SCANS_DIR/$domain/metadata.csv" ]; then
    meta_count=$(wc -l < "$DAY_ONE_SCANS_DIR/$domain/metadata.csv")
    # Subtract one from meta_count unless it's zero
    if [ "$meta_count" -gt 0 ]; then
        ((meta_count--))
    fi
else
    echo "File '$DAY_ONE_SCANS_DIR/$domain/metadata.csv' not found or is not readable."
    meta_count=0
fi


###################################################################################
#Breach Data Question
echo " "
echo " "
echo " "
echo " "
echo "${GREEN}================ All Tasks Complete ================${NC}"
echo " "
echo "${ORANGE}               Reconnaissance Results               ${NC}"
echo " "
echo "${RED}DNS Records: ${NC}$dnsrecords"
echo "${RED}Hosts= ${NC}$hosts_count"
echo "${RED}Squatting= ${NC}$squatting_count"
echo "${RED}Subdomains= ${NC}$subdomains_count"
echo "${RED}Emails= ${NC}$emails_count"
echo "${RED}Usernames= ${NC}$usernames_count"
echo "${RED}Registered Domains= ${NC}$registered_domains"
echo "${RED}Valid Users= ${NC}$valid_users"
echo "${RED}Breach Records= ${NC}$breach_data_count"
echo "${RED}Metadata= ${NC}$meta_count"

echo " "
echo "+-----------------------------------------------------+"
echo " "
echo "${ORANGE}                 Breach Data Dates                 ${NC}"
echo " "
echo "Myspace: ${RED}2016${NC}"
echo "Zynga: ${RED}2018${NC}"
echo "MyFitnessPal: ${RED}2018${NC}"
echo "Adobe: ${RED}2019${NC}"
echo "Linkedin: ${RED}2021/2023${NC}"


#Create HTML file
echo " "
echo " "
echo " "
echo " "
echo "${GREEN}============== Creating HTML Document =============${NC}"
echo " "
echo " "
# Start of the HTML file
echo "<!DOCTYPE html>" > "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<html lang='en'>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<head>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <meta charset='UTF-8'>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <meta http-equiv='X-UA-Compatible' content='IE=edge'>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <title>Security Report</title>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <style>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        body { " >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            font-family: Arial, sans-serif;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            margin: 40px;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            background-color: black;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            color: white;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        #toc { color: #f0f0f0; }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        #toc-section a { color: #3498db; text-decoration: none; }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        #toc-section { color: #3498db; }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        h1 { color: darkblue; }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        h2 { color: darkred; }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        p { line-height: 1.6; }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        section {" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            background-color: #202020;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            border-radius: 5px;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            padding: 20px;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            margin-bottom: 20px;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        pre {" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            background-color: #303030;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            padding: 15px;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "            border-radius: 5px;" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "        }" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    </style>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "</head>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<body>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"

# Table of Contents
echo "<div id='toc-section'>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<h1 id='toc-section'>Table of Contents</h1>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<ul>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#hosts'>Hosts</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#dns'>DNS Information</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#dnsrecords'>DNS Records</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#subdomains'>Subdomains</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#emails'>Potential Emails</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#usernames'>Potential Usernames</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#squatting'>Squatting</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#registered_domains'>Registered Domains</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "    <li><a href='#valid_users'>Valid User Accounts</a></li>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "</ul>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "</div>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"


echo "<h1 id='toc-section'>Summary of Results</h1>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>DNS Records:</b> ( $dnsrecords )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Hosts:</b> ( $hosts_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Squatting:</b> ( $squatting_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Subdomains:</b> ( $subdomains_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Potential Emails:</b> ( $emails_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Potential Usernames:</b> ( $usernames_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Registered Domains:</b> ( $registered_domains )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Valid Users:</b> ( $valid_users )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Breach Records:</b> ( $breach_data_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "<p><b>Metadata:</b> ( $meta_count )</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"

# Insert contents
if [ -r "$DAY_ONE_SCANS_DIR/$domain/hosts.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"    
    echo "    <h2 id='hosts'>Hosts:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/hosts.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No hosts data found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/DNSInfo" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='dns'>DNS Info and Zone Transfer:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/DNSInfo" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No DNS data found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='dnsrecords'>DNS Records:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/dnsrecords.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No DNS data found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='subdomains'>Subdomains:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/subdomains.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No Subdomains found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/emails.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='emails'>Potential Emails:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/emails.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No Emails found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='usernames'Potential Usernames:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/usernames.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No Usernames found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/squatting.csv" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='squatting'>Squatting:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/squatting.csv" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No Squatting found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/RegisteredDomainsSorted.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='registered_domains'>Registered Domains:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/RegisteredDomainsSorted.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No Registered Domains found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

if [ -r "$DAY_ONE_SCANS_DIR/$domain/validusers.txt" ]; then
    echo "<section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <h2 id='valid_users'>Valid User Accounts:</h2>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    <pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    cat "$DAY_ONE_SCANS_DIR/$domain/validusers.txt" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "    </pre>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
    echo "</section>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
else
    echo "    <p>No Valid Users found.</p>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
fi

# Close the HTML file
echo "</body>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"
echo "</html>" >> "$DAY_ONE_SCANS_DIR/$domain/Report.html"

# Print a completion message
echo "HTML report generated at $DAY_ONE_SCANS_DIR/$domain/Report.html"

# Zip all files
echo " "
echo " "
echo " "
echo " "
echo "${GREEN}================== Zipping Files ==================${NC}"
# Define the zip filename
zip_filename="${domain}_OSINT.zip"

cd "$DAY_ONE_SCANS_DIR/$domain"

# Check if the zip file already exists
while [ -e "$zip_filename" ]; do
    # Generate a random 4-character string (you can adjust the length as needed)
    random_chars="$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 4)"
    
    # Append the random string to the zip filename
    zip_filename="${domain}_OSINT_${random_chars}.zip"
done

# Create the zip archive containing all files in the current directory and subdirectories
zip -r "$zip_filename" * > /dev/null 2>&1

# Navigate back to the original directory, if needed
cd - > /dev/null
# Inform the user that the process is complete
echo " "
echo " "
echo "${ORANGE}All files have been zipped into${NC} ${RED}$zip_filename${NC}"
