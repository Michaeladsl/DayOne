#!/bin/bash

# Creator: Michael Raines
CURRENT_VERSION="1.5"
REPO_URL="https://raw.githubusercontent.com/Michaeladsl/DayOne/main/DayOne.sh"

# Function to check the current version against the latest version on GitHub
check_version() {
    # Fetch the line containing the CURRENT_VERSION string from the remote repository
    LATEST_VERSION=$(curl -s "$REPO_URL" | grep -E '^CURRENT_VERSION="' | cut -d '"' -f 2)
    
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        echo "Your script is outdated. Your version is ${RED}$CURRENT_VERSION${NC}, latest version is $LATEST_VERSION."
        echo "Please consider updating for new features and fixes."
    fi
}

regions_flag=false  # Default value
DISABLED_TOOLS=""
list_tools_flag=false # Default value
verbose_mode=false  # Default value
new_tool_downloaded=0


RED=$(tput setaf 1)
GREEN=$(tput setaf 2; tput bold)
ORANGE=$(tput setaf 3)
YELLOW=$(tput setaf 3; tput bold)
CYAN=$(tput setaf 6)
NC=$(tput sgr0) # No Color

while getopts "D:rthv" flag; do
    case "$flag" in
        D) DISABLED_TOOLS="$OPTARG" ;;
        r) regions_flag=true ;;
        t) list_tools_flag=true ;;
        v) verbose_mode=true ;;
        h) echo "Usage: $0 [-D <tool_name>] [-r] [-t] [-v]"
           echo " -D <tool_name> : Disable a specific tool (e.g., pymeta, cloudenum)"
           echo " -r             : Enable all regions in cloud_enum (slow)"
           echo " -t             : List all available tools that can be disabled"
           echo " -h             : Show this help message"
           echo " -v             : Verbose Mode (for error checking)"
           exit 0 ;;
        *) echo "Usage: $0 [-D <tool_name>] [-r] [-t] [-v]"
           exit 1 ;;
    esac
done

# Iterate over all provided arguments
for arg in "$@"; do
    case $arg in
        -h)
            echo "Usage: scriptname [options]"
            echo "  -h    Show this help message"
            echo "  -t    Show some other type of information"
            # ... other options ...
            exit 0
            ;;
        -t)
            echo "Available tools that can be disabled with -D:"
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
            exit 0
            ;;
        *)
            # unrecognized option
            ;;
    esac
done

# Convert the comma-separated list into an array
IFS=',' read -ra DISABLED_ARRAY <<< "$DISABLED_TOOLS"

# Reset argument index so $1 will refer to the first non-option argument
shift $((OPTIND-1))

is_tool_disabled() {
    local tool="$1"
    for disabled_tool in "${DISABLED_ARRAY[@]}"; do
        if [[ "$disabled_tool" == "$tool" ]]; then
            return 0  # 0 is true in bash
        fi
    done
    return 1  # 1 is false in bash
}


if [ "$verbose_mode" = true ]; then
    set -x
fi

# URLs for each tool
CrossLinked_url="https://github.com/m8sec/CrossLinked.git"
dnscan_url="https://github.com/rbsec/dnscan.git"
cloud_enum_url="https://github.com/initstring/cloud_enum.git"
onedrive_user_enum_url="https://github.com/nyxgeek/onedrive_user_enum.git"
subfinder_url="https://github.com/projectdiscovery/subfinder.git"
crt_sh_url="https://github.com/az7rb/crt.sh.git"

# Function to clone a repository if its directory doesn't exist
clone_repo_if_missing() {
    local dir_name="$1"
    local repo_url="$2"
    if [ ! -d "$dir_name" ]; then
        echo "Directory for tool $dir_name not found. Cloning repository..."
        git clone "$repo_url"
        if [ $? -ne 0 ]; then
            echo "${RED}Git clone of $dir_name failed. Exiting...${NC}"
            exit 1
        fi
        return 1  # Return 1 to indicate that a new tool was cloned
    fi
    return 0  # Return 0 to indicate no new tool was cloned
}

# Check for the presence of DayOneScans directory
if [ ! -d "DayOneScans" ]; then
    echo "DayOneScans directory not found. Creating..."
    mkdir -p DayOneScans/tools
    cd DayOneScans/tools

    
    # Clone repositories
    echo "Cloning required repositories..."
    git clone $CrossLinked_url
    if [ $? -ne 0 ]; then
        echo "${RED}Git clone of crosslinked failed. Exiting...${NC}"
        exit 1
    fi

    git clone $dnscan_url
    if [ $? -ne 0 ]; then
        echo "${RED}Git clone of dnscan failed. Exiting...${NC}"
        exit 1
    fi

    git clone $cloud_enum_url
    if [ $? -ne 0 ]; then
        echo "${RED}Git clone of cloud_enum failed. Exiting...${NC}"
        exit 1
    fi

    git clone $onedrive_user_enum_url
    if [ $? -ne 0 ]; then
        echo "${RED}Git clone of onedrive_enum failed. Exiting...${NC}"
        exit 1
    fi

    git clone $subfinder_url
    if [ $? -ne 0 ]; then
        echo "${RED}Git clone of subfinder failed. Exiting...${NC}"
        exit 1
    fi

    git clone $crt_sh_url
    if [ $? -ne 0 ]; then
        echo "${RED}Git clone of crt.sh failed. Exiting...${NC}"
        exit 1
    fi

    #Update Golang
    sudo apt update && sudo apt install golang -y > /dev/null 2>&1

    # Install subfinder
    cd subfinder/v2/cmd/subfinder
    go build .
    sudo mv subfinder /usr/local/bin/
    cd ../../../../../..


    sudo pip3 install pymetasec > /dev/null 2>&1

    # Combine requirements.txt files
   {
    cat DayOneScans/tools/CrossLinked/requirements.txt
    echo
    cat DayOneScans/tools/dnscan/requirements.txt
    echo
    cat DayOneScans/tools/cloud_enum/requirements.txt
    echo
    cat DayOneScans/tools/onedrive_user_enum/requirements.txt
    } > DayOneScans/tools/requirements.txt


fi


# For new tools! Check run function for newly added tools if DayOneScans already exists
if [ -d "DayOneScans/tools" ]; then
    cd DayOneScans/tools

    # Check existence of newly added tools (examples)
    clone_repo_if_missing "crt.sh" "git clone $crt_sh_url"
    if [ $? -eq 1 ]; then new_tool_downloaded=1; fi
    
    #clone_repo_if_missing "dnscan" "$dnscan_url"
    #if [ $? -eq 1 ]; then new_tool_downloaded=1; fi

    #clone_repo_if_missing "cloud_enum" "$cloud_enum_url"
    #if [ $? -eq 1 ]; then new_tool_downloaded=1; fi

    # Change back to original directory
    cd -
fi

# If a new tool was downloaded, then update requirements.txt and install new packages
if [ $new_tool_downloaded -eq 1 ]; then
    cd DayOneScans/tools  # Make sure to be in the correct directory
    # Initialize empty combined_requirements.txt
    echo "" > combined_requirements.txt
    
    # Loop through all directories in the current folder (DayOneScans/tools)
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
    pip install -r combined_requirements.txt
    cd -  # Change back to original directory
fi

# Modify azure_regions.py and gcp_regions.py
if [ "$regions_flag" = true ]; then
    tool_directory_path="DayOneScans/tools/cloud_enum/enum_tools"
    azure_regions_file="$tool_directory_path/azure_regions.py"
    gcp_regions_file="$tool_directory_path/gcp_regions.py"

    # Step 1: Create Backup Copies
    cp "$azure_regions_file" "${azure_regions_file}.backup"
    cp "$gcp_regions_file" "${gcp_regions_file}.backup"

    # Continue with your sed commands to modify the files
    sed -i '$d; $d; $d; $d' "$azure_regions_file"
    sed -i '$d; $d; $d; $d' "$gcp_regions_file"
fi


# Update and install necessary packages
echo "Updating and installing necessary packages..."
sudo apt update > /dev/null 2>&1
sudo apt install -y urlcrazy > /dev/null 2>&1
sudo apt-get install exiftool -y > /dev/null 2>&1
sudo apt install -y figlet > /dev/null 2>&1
sudo apt install -y dnstwist > /dev/null 2>&1
sudo apt install -y subjack > /dev/null 2>&1
sudo apt install -y dnsrecon > /dev/null 2>&1
sudo apt install -y jq > /dev/null 2>&1

# Install tool dependencies
echo "Installing tool dependencies..."
pip3 install -r DayOneScans/tools/requirements.txt > /dev/null 2>&1
pip3 install -r DayOneScans/tools/cloud_enum/requirements.txt > /dev/null 2>&1

# Install Pymeta and fix errors
sudo pip3 install pymetasec > /dev/null 2>&1
sleep 5

# Run pymeta command and capture the error
error_output=$(pymeta 2>&1)

# Extract the file path from the error output
file_path=$(echo "$error_output" | grep -o 'File ".*__init__.py"' | awk -F'"' '{print $2}')

# Check if file_path starts with /.local and prepend ~ if it does
if [[ "$file_path" == /.local* ]]; then
    file_path="~$file_path"
fi

# Check if file_path has been set and if it's not empty
if [[ -n "$file_path" ]]; then
    # Modify the problematic file
    sudo sed -i '140s/^[[:space:]]*//' "$file_path"
else
    echo " "
fi

TMUX_CONF_PATH=$(sudo find / -type f \( -name ".tmux.conf" -o -name "tmux.conf" \) 2>/dev/null | head -n 1)

# Check if the file was found.
if [[ ! -z "$TMUX_CONF_PATH" ]]; then
    # Check if the required line already exists using sudo.
    if ! sudo grep -q "@retain-ansi-escapes" "$TMUX_CONF_PATH"; then
        echo "Appending configuration to tmux.conf..."
        
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

# Prompt the user for a domain
read -p "${ORANGE}Enter the domain (domain.com): ${NC}" domain
echo " "
echo " "
# Check if the supplied domain is a directory and create it if it doesn't exist
if [ ! -d "DayOneScans/$domain" ]; then
    echo "Creating directory for domain: $domain"
    mkdir -p "DayOneScans/$domain"
fi

echo " "
echo " "

if ! is_tool_disabled "crosslinked"; then

    # Prompt the user to choose a format for {f}{last}
    echo " ${ORANGE}=========== Choose a format for {f}{last}: ===========${NC}"
    echo " 1. {f}{last}"
    echo " 2. {first}.{last}"
    echo " 3. {first}{last}"
    echo " 4. {first}{l}"
    echo " 5. {first}"
    echo " "
    echo " "
    read -p "${ORANGE}Enter the option (1/2/3/4/5): ${NC}" format_option
    echo " "
    echo " "

    # Determine the format based on the user's choice
    case $format_option in
        1) format="{f}{last}" ;;
        2) format="{first}.{last}" ;;
        3) format="{first}{last}" ;;
        4) format="{first}{l}" ;;
        5) format="{first}" ;;
        *) echo "Invalid option. Using default format {f}{last}"; format="{f}{last}" ;;
    esac

    # Construct the email format
    email_format="${format}@${domain}"
    echo " "
    echo " "

    # Prompt the user for the organization name as it appears on LinkedIn or use the domain
    read -p "${ORANGE}Enter the organization name as it appears on${NC} ${RED}LinkedIn${NC} ${ORANGE}or re-enter the domain:${NC} " org_name
    echo " "
    echo " "
fi

read -p "${ORANGE}Do you want to attempt the Microsoft Direct Send vulnerability?${NC} (${GREEN}YES${NC}/${RED}NO${NC}): " direct_send
echo " "
echo " "
direct_send=$(echo "$direct_send" | tr '[:upper:]' '[:lower:]')

# Check if the user wants to attempt direct send vulnerability
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

# Prompt the user for permission to test cloud environments
read -p "${ORANGE}Do you have permission to test cloud environments (AADUserEnum)?${NC}(${GREEN}YES${NC}/${RED}NO${NC})${YELLOW}:${NC} " permission
echo " "
echo " "
echo " "
echo " "
echo "${GREEN}=========== Inputing Data ===========${NC}"
# Install and Import AADInternals
tmux new-session -d -s aadint_session1 'pwsh'
tmux send-keys -t aadint_session1 "Install-Module AADInternals" C-m
sleep 8
tmux send-keys -t aadint_session1 "A" C-m
sleep 5
tmux send-keys -t aadint_session1 "Import-Module AADInternals" C-m
##################################################################
##################################################################
echo "Complete"

# Run pymeta.py with user-provided domain
if ! is_tool_disabled "pymeta"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Running Pymeta ==========${NC}"
    echo " "
    echo " "
    pymeta -j 7 -d "$domain" -f "DayOneScans/$domain/metadata.csv" -s all
fi

# Run crosslinked.py with user-selected format and user-supplied domain or organization name
if ! is_tool_disabled "crosslinked"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Running Crosslinked ==========${NC}"
    echo " "
    echo " "
    python DayOneScans/tools/CrossLinked/crosslinked.py -j 7 -f "${format}@${domain}" "$org_name" -o "DayOneScans/$domain/emails"


    echo " "
    echo "Processing and cleaning up emails.txt..."
    cat "DayOneScans/$domain/emails.txt" | tr '[:upper:]' '[:lower:]' | sort -u > "DayOneScans/$domain/emails_tmp.txt"
    mv "DayOneScans/$domain/emails_tmp.txt" "DayOneScans/$domain/emails.txt"
    cat "DayOneScans/$domain/emails.txt" | sed "s/@$domain//g" | sort -u > "DayOneScans/$domain/usernames.txt"
fi
echo " "
echo " "
echo " "
echo " "
# Run dehashed.py if it exists, otherwise search for it and copy if found
if ! is_tool_disabled "dehashed"; then
    if [ -f "DayOneScans/tools/dehashed.py" ]; then
        echo " "
        echo " "
        echo "${GREEN}========== Running Dehashed ==========${NC}"
        python3 DayOneScans/tools/dehashed.py -d "$domain" -o "DayOneScans/$domain/${domain}BreachData.csv"
    else
        echo " "
        find ~/ -name "dehashed.py" -exec cp {} DayOneScans/tools/dehashed.py \; 2>/dev/null;
        if [ -f "DayOneScans/tools/dehashed.py" ]; then
            echo "${GREEN}========== Running Dehashed ==========${NC}"
            python3 DayOneScans/tools/dehashed.py -d "$domain" -o "DayOneScans/$domain/${domain}BreachData.csv"
        else
            cat "DayOneScans/$domain/emails.txt" | sed "s/@$domain//g" | sort -u > "DayOneScans/$domain/usernames_tmp.txt"
            mv "DayOneScans/$domain/usernames_tmp.txt" "DayOneScans/$domain/usernames.txt"
            echo "${RED}(dehashed.py not found. Moving on to the next script.)${NC}"
        fi
    fi
fi


echo " "
echo " "
# Extract email addresses from domainBreachData.csv and append to emails.txt
if [ -f "DayOneScans/$domain/${domain}BreachData.csv" ]; then
    echo "${YELLOW}Extracting email addresses from domainBreachData.csv...${NC}"
    grep -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}' "DayOneScans/$domain/${domain}BreachData.csv" | grep -v "^[0-9]" | sort -u >> "DayOneScans/$domain/emails.txt"
    tr '[:upper:]' '[:lower:]' < "DayOneScans/$domain/emails.txt" > "DayOneScans/$domain/emails_lower.txt"
    mv "DayOneScans/$domain/emails_lower.txt" "DayOneScans/$domain/emails.txt"
    sort -u "DayOneScans/$domain/emails.txt" -o "DayOneScans/$domain/emails.txt"
    cat "DayOneScans/$domain/emails.txt" | sed -e "s/@$domain//g" -e "s/www\.//g" | sort -u > "DayOneScans/$domain/usernames.txt"
    sort -u "DayOneScans/$domain/usernames.txt" -o "DayOneScans/$domain/usernames.txt"
fi

if [ -f "DayOneScans/$domain/usernames.txt" ]; then
    tr '[:upper:]' '[:lower:]' < "DayOneScans/$domain/usernames.txt" > "DayOneScans/$domain/usernames_lower.txt"
    mv "DayOneScans/$domain/usernames_lower.txt" "DayOneScans/$domain/usernames.txt"
    sort -u "DayOneScans/$domain/usernames.txt" -o "DayOneScans/$domain/usernames.txt"
    sed -e 's/@.*//' -e 's/www\.//' "DayOneScans/$domain/usernames.txt" > "DayOneScans/$domain/cleaned_usernames.txt"
    mv "DayOneScans/$domain/cleaned_usernames.txt" "DayOneScans/$domain/usernames.txt"
    sort -u "DayOneScans/$domain/usernames.txt" -o "DayOneScans/$domain/usernames.txt"
    
fi

if [ -f "DayOneScans/$domain/usernames.txt" ]; then
    # Append usernames with "@domain" to emails.txt
    while read username; do
        echo "${username}@$domain"
    done < "DayOneScans/$domain/usernames.txt" >> "DayOneScans/$domain/emails.txt"

    # Remove duplicates from emails.txt
    sort -u "DayOneScans/$domain/emails.txt" -o "DayOneScans/$domain/emails.txt"
fi


# Determine the directory of the script
SCRIPTDIR=$(dirname "$(realpath "$0")")

# Run onedrive_enum.py with user-supplied domain and usernames.txt
if ! is_tool_disabled "onedrive_enum"; then
    echo " "
    echo " "
    echo "${GREEN}========== Finding Valid User Accounts ==========${NC}"
    echo " "
    echo " "
    cd DayOneScans/tools/onedrive_user_enum
    python onedrive_enum.py -d "$domain" -U $SCRIPTDIR/DayOneScans/$domain/usernames.txt -r
    mv emails* $SCRIPTDIR/DayOneScans/$domain/emails_valid.txt
    cd - > /dev/null
fi

sort -u DayOneScans/$domain/emails_valid.txt -o DayOneScans/$domain/emails_valid.txt

permission=$(echo "$permission" | tr '[:upper:]' '[:lower:]')

# Check if permission is granted
if [ "$permission" == "yes" ]; then
    # Send the PowerShell command to the TMUX session
    if ! is_tool_disabled "AADUserEnum"; then
        tmux send-keys -t aadint_session1 "Get-Content DayOneScans/$domain/emails.txt | Invoke-AADIntUserEnumerationAsOutsider | Export-Csv -Path DayOneScans/$domain/AADuserenum.txt -NoTypeInformation" C-m
    
        # Wait for the command to finish (you can adjust the sleep time as needed)
        sleep 20

        echo " "
        echo " "
    fi
else
    echo " "
    echo " "
    echo "${RED}(Skipping user enumeration, permission was not granted.)${NC}"
fi


# Run cloud_enum.py with specified parameters
cloud_enum_keyword=$(echo $domain | cut -d "." -f "1")
if ! is_tool_disabled "cloudenum"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Running cloud_enum ==========${NC}"
    echo " "
    echo " "
    script -c "python DayOneScans/tools/cloud_enum/cloud_enum.py -k '$domain' -k '$cloud_enum_keyword' -t 25 -l 'DayOneScans/$domain/CloudEnum.Log' | grep -v -e '\[!\] DNS Timeout on' -e '\[!\] Connection error on' -e '^HTTPConnectionPool'" -f DayOneScans/$domain/CloudEnumFULL.txt

fi


# Read emails_valid.txt and extract valid usernames
if [ -f "DayOneScans/$domain/emails_valid.txt" ]; then
    sort -u DayOneScans/$domain/emails_valid.txt -o DayOneScans/$domain/emails_valid.txt
    sed "s/@${domain}//" "DayOneScans/$domain/emails_valid.txt" > "DayOneScans/$domain/validusers.txt"
fi

# Read AADuserenum.txt and extract valid usernames
if [ -f "DayOneScans/$domain/AADuserenum.txt" ]; then
    awk -F',' '$2 ~ /"True"/ { gsub(/"/, "", $1); print $1 }' "DayOneScans/$domain/AADuserenum.txt" >> "DayOneScans/$domain/validusers.txt"
    awk -F'@' '{print $1}' "DayOneScans/$domain/validusers.txt" | sort > "DayOneScans/$domain/temp.txt" && mv "DayOneScans/$domain/temp.txt" "DayOneScans/$domain/validusers.txt"

fi

# Remove domain from usernames and sort
if [ -f "DayOneScans/$domain/validusers.txt" ]; then
    sed -i "s/@$domain//g" "DayOneScans/$domain/validusers.txt"
    sort -u "DayOneScans/$domain/validusers.txt" -o "DayOneScans/$domain/validusers.txt"
    echo " "
    echo " "
fi



# Run dnscan.py with specified parameters
if ! is_tool_disabled "dnscan"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Gathering DNS Info ==========${NC}"
    echo " "
    echo " "
    python DayOneScans/tools/dnscan/dnscan.py -d "$domain" -n -o "DayOneScans/$domain/DNSInfo" -t 50
    awk -F" - " '/ - / {print $2}' "DayOneScans/$domain/DNSInfo" > "DayOneScans/$domain/temp_dnsinfo.txt"

    dnsrecon -d "$domain" -t std > "DayOneScans/$domain/dnsrecon.txt"

    # Check if the file 'dnsrecon.txt' exists and is readable
    if [ -r "DayOneScans/$domain/dnsrecon.txt" ]; then
        grep -oP '(MX|A|TXT|SRV|NS|SOA) \K[^ ]*\.com' "DayOneScans/$domain/dnsrecon.txt" > "DayOneScans/$domain/extracted_dnsrecords.txt"
        sort -u DayOneScans/$domain/temp_dnsinfo.txt DayOneScans/$domain/extracted_dnsrecords.txt > DayOneScans/$domain/dnsrecords.txt
        rm DayOneScans/$domain/temp_dnsinfo.txt
        grep -E -o "[a-zA-Z0-9.-]+\.$domain" "DayOneScans/$domain/DNSInfo" >> "DayOneScans/$domain/subdomains.txt"
    fi

fi

# Extracting email for direct send attempt
smtp_server=$(grep -E -o '[A-Za-z0-9.-]+\.mail\.protection\.outlook\.com' "DayOneScans/$domain/DNSInfo" | grep -o -E '[A-Za-z0-9-]+\.mail\.protection\.outlook\.com')


# Run subfinder with specified parameters
if ! is_tool_disabled "subfinder"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Looking for Subdomains ==========${NC}"
    echo " "
    echo " "
    subfinder -d "$domain" -all -oI -active -o "DayOneScans/$domain/subfindersubs"
    grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' "DayOneScans/$domain/subfindersubs" | sort -u > "DayOneScans/$domain/hosts.txt"
fi

if ! is_tool_disabled "crt.sh"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo " "
    echo " "
    cd DayOneScans/tools/crt.sh
    chmod +x crt.sh
    ./crt.sh -d $domain
    cd -
    mv DayOneScans/tools/crt.sh/output/domain.$domain.txt DayOneScans/$domain/crtsubdomains.txt
fi

cat "DayOneScans/$domain/crtsubdomains.txt" >> "DayOneScans/$domain/subdomains.txt"

# Extract IPs from DNSInfo and append to hosts.txt
grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' "DayOneScans/$domain/DNSInfo" | sort -u >> "DayOneScans/$domain/hosts.txt"
grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' "DayOneScans/$domain/dnsrecon.txt" | sort -u >> "DayOneScans/$domain/hosts.txt"


# Sort and remove duplicates from hosts.txt
sort -u "DayOneScans/$domain/hosts.txt" -o "DayOneScans/$domain/hosts.txt"

# Extract subdomains and create subdomains.txt
cut -d ',' -f 1 "DayOneScans/$domain/subfindersubs" | sort -u >> "DayOneScans/$domain/subdomains.txt"

# Sort and remove duplicates from subdomains.txt
sort -u "DayOneScans/$domain/subdomains.txt" -o "DayOneScans/$domain/subdomains.txt"

# Check Subdomain Takeover
if ! is_tool_disabled "subjack"; then
    echo " "
    echo " "
    echo " "
    echo " "
    echo "${GREEN}========== Checking For Subdomain Takeover ==========${NC}"
    echo " "
    echo " "
    subjack -w "DayOneScans/$domain/subdomains.txt" -t 100 -timeout 30 -o "DayOneScans/$domain/subtakeover.txt" -ssl -m -c /usr/share/subjack/fingerprints.json -v 1 >/dev/null 2>&1

    # Display the first 10 lines of subtakeover.txt
    head -n 10 "DayOneScans/$domain/subtakeover.txt"

    # Display lines from subtakeover.txt that begin with [Vulnerable]
    grep -v '^\[Not Vulnerable\]' "DayOneScans/$domain/subtakeover.txt"
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
    dnstwist -o DayOneScans/$domain/squatting.csv -f csv -t 20 -r "$domain"
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
    http_status=$(curl -w "%{http_code}" -o "DayOneScans/$domain/DNSMap.png" "https://dnsdumpster.com/static/map/$domain.png")
    
    # Check if the HTTP status code is 200 (OK)
    if [ "$http_status" -eq 200 ]; then
        echo " "
        echo " "
        echo "${ORANGE}DNSMap image downloaded to DayOneScans/$domain/DNSMap.png${NC}"
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
    tmux send-keys -t aadint_session2 "Get-AADIntTenantDomains -Domain $domain | Out-File -FilePath DayOneScans/$domain/registereddomains.txt" C-m

    # Wait for the command to finish
    sleep 20  # You can adjust the sleep time as needed
    tmux kill-session -t aadint_session2

    grep -Eo '[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "DayOneScans/$domain/registereddomains.txt" > "DayOneScans/$domain/extracted_domains.txt"
    mv "DayOneScans/$domain/extracted_domains.txt" "DayOneScans/$domain/RegisteredDomainsSorted.txt"
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


if [ -n "$smtp_server" ]; then
    # Check if the direct_send flag is set to "yes"
    if [ "$direct_send" == "yes" ]; then
        echo "${GREEN}========= Direct Send Vulnerability Test =========${NC}"
        echo " "
        echo " "
        tmux new-session -d -s mail_session 'pwsh'
        sleep 4
        tmux send-keys -t mail_session "Send-MailMessage -SmtpServer $smtp_server -To $poc_email -From test@$domain -Subject 'Test Email' -Body 'This is a test as part of the current round of testing. Please forward this to $employee_email' -BodyAsHTML" C-m
        sleep 10
        tmux capture-pane -t mail_session -e -p > "DayOneScans/$domain/DirectSend.txt"
        cat "DayOneScans/$domain/DirectSend.txt"
    fi
else
    echo "Not Eligible For Direct Send Attempt"
fi


tmux kill-session -t mail_session


# Restoring original files for cloud_enum
if [ "$regions_flag" = true ]; then
    mv "${azure_regions_file}.backup" "$azure_regions_file"
    mv "${gcp_regions_file}.backup" "$gcp_regions_file"
fi

# Counting files contents for display
if [ -r "DayOneScans/$domain/dnsrecords.txt" ]; then
    dnsrecords=$(wc -l < "DayOneScans/$domain/dnsrecords.txt")
else
    echo "File 'DayOneScans/$domain/dnsrecords.txt' not found or is not readable."
    dnsrecords=0
fi

if [ -r "DayOneScans/$domain/hosts.txt" ]; then
    hosts_count=$(wc -l < "DayOneScans/$domain/hosts.txt")
else
    echo "File 'DayOneScans/$domain/hosts.txt' not found or is not readable."
    hosts_count=0
fi

if [ -r "DayOneScans/$domain/subdomains.txt" ]; then
    subdomains_count=$(wc -l < "DayOneScans/$domain/subdomains.txt")
else
    echo "File 'DayOneScans/$domain/subdomains.txt' not found or is not readable."
    subdomains_count=0
fi

if [ -r "DayOneScans/$domain/emails.txt" ]; then
    emails_count=$(wc -l < "DayOneScans/$domain/emails.txt")
else
    echo "File 'DayOneScans/$domain/emails.txt' not found or is not readable."
    emails_count=0
fi

if [ -r "DayOneScans/$domain/usernames.txt" ]; then
    usernames_count=$(wc -l < "DayOneScans/$domain/usernames.txt")
else
    echo "File 'DayOneScans/$domain/usernames.txt' not found or is not readable."
    usernames_count=0
fi

if [ -r "DayOneScans/$domain/squatting.csv" ]; then
    squatting_count=$(wc -l < "DayOneScans/$domain/squatting.csv")
else
    echo "File 'DayOneScans/$domain/squatting.csv' not found or is not readable."
    squatting_count=0
fi

if [ -r "DayOneScans/$domain/RegisteredDomainsSorted.txt" ]; then
    registered_domains=$(wc -l < "DayOneScans/$domain/RegisteredDomainsSorted.txt")
else
    echo "File 'DayOneScans/$domain/RegisteredDomainsSorted.txt' not found or is not readable."
    registered_domains=0
fi

if [ -r "DayOneScans/$domain/validusers.txt" ]; then
    valid_users=$(wc -l < "DayOneScans/$domain/validusers.txt")
else
    echo "File 'DayOneScans/$domain/validusers.txt' not found or is not readable."
    valid_users=0
fi

if [ -r "DayOneScans/$domain/${domain}BreachData.csv" ]; then
    breach_data_count=$(($(wc -l < "DayOneScans/$domain/${domain}BreachData.csv") - 1))
else
    echo "File 'DayOneScans/$domain/${domain}BreachData.csv' not found or is not readable."
    breach_data_count=0  # Set to 0 if the file doesn't exist
fi

if [ -r "DayOneScans/$domain/metadata.csv" ]; then
    meta_count=$(wc -l < "DayOneScans/$domain/metadata.csv")
else
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
echo "<!DOCTYPE html>" > "DayOneScans/$domain/Report.html"
echo "<html lang='en'>" >> "DayOneScans/$domain/Report.html"
echo "<head>" >> "DayOneScans/$domain/Report.html"
echo "    <meta charset='UTF-8'>" >> "DayOneScans/$domain/Report.html"
echo "    <meta http-equiv='X-UA-Compatible' content='IE=edge'>" >> "DayOneScans/$domain/Report.html"
echo "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>" >> "DayOneScans/$domain/Report.html"
echo "    <title>Security Report</title>" >> "DayOneScans/$domain/Report.html"
echo "    <style>" >> "DayOneScans/$domain/Report.html"
echo "        body { " >> "DayOneScans/$domain/Report.html"
echo "            font-family: Arial, sans-serif;" >> "DayOneScans/$domain/Report.html"
echo "            margin: 40px;" >> "DayOneScans/$domain/Report.html"
echo "            background-color: black;" >> "DayOneScans/$domain/Report.html"
echo "            color: white;" >> "DayOneScans/$domain/Report.html"
echo "        }" >> "DayOneScans/$domain/Report.html"
echo "        #toc { color: #f0f0f0; }" >> "DayOneScans/$domain/Report.html"
echo "        #toc-section a { color: #3498db; text-decoration: none; }" >> "DayOneScans/$domain/Report.html"
echo "        #toc-section { color: #3498db; }" >> "DayOneScans/$domain/Report.html"
echo "        h1 { color: darkblue; }" >> "DayOneScans/$domain/Report.html"
echo "        h2 { color: darkred; }" >> "DayOneScans/$domain/Report.html"
echo "        p { line-height: 1.6; }" >> "DayOneScans/$domain/Report.html"
echo "        section {" >> "DayOneScans/$domain/Report.html"
echo "            background-color: #202020;" >> "DayOneScans/$domain/Report.html"
echo "            border-radius: 5px;" >> "DayOneScans/$domain/Report.html"
echo "            padding: 20px;" >> "DayOneScans/$domain/Report.html"
echo "            margin-bottom: 20px;" >> "DayOneScans/$domain/Report.html"
echo "        }" >> "DayOneScans/$domain/Report.html"
echo "        pre {" >> "DayOneScans/$domain/Report.html"
echo "            background-color: #303030;" >> "DayOneScans/$domain/Report.html"
echo "            padding: 15px;" >> "DayOneScans/$domain/Report.html"
echo "            border-radius: 5px;" >> "DayOneScans/$domain/Report.html"
echo "        }" >> "DayOneScans/$domain/Report.html"
echo "    </style>" >> "DayOneScans/$domain/Report.html"
echo "</head>" >> "DayOneScans/$domain/Report.html"
echo "<body>" >> "DayOneScans/$domain/Report.html"

# Table of Contents
echo "<div id='toc-section'>" >> "DayOneScans/$domain/Report.html"
echo "<h1 id='toc-section'>Table of Contents</h1>" >> "DayOneScans/$domain/Report.html"
echo "<ul>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#hosts'>Hosts</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#dns'>DNS Information</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#dnsrecords'>DNS Records</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#subdomains'>Subdomains</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#emails'>Emails</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#usernames'>Usernames</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#squatting'>Squatting</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#registered_domains'>Registered Domains</a></li>" >> "DayOneScans/$domain/Report.html"
echo "    <li><a href='#valid_users'>Valid User Accounts</a></li>" >> "DayOneScans/$domain/Report.html"
echo "</ul>" >> "DayOneScans/$domain/Report.html"
echo "</div>" >> "DayOneScans/$domain/Report.html"


# Add summary of results
echo "<h1 id='toc-section'>Summary of Results</h1>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>DNS Records:</b> ( $dnsrecords )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Hosts:</b> ( $hosts_count )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Squatting:</b> ( $squatting_count )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Subdomains:</b> ( $subdomains_count )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Emails:</b> ( $emails_count )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Usernames:</b> ( $usernames_count )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Registered Domains:</b> ( $registered_domains )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Valid Users:</b> ( $valid_users )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Breach Records:</b> ( $breach_data_count )</p>" >> "DayOneScans/$domain/Report.html"
echo "<p><b>Metadata:</b> ( $meta_count )</p>" >> "DayOneScans/$domain/Report.html"

# Insert contents
# Insert contents
if [ -r "DayOneScans/$domain/hosts.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"    
    echo "    <h2 id='hosts'>Hosts:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/hosts.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No hosts data found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/DNSInfo" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='dns'>DNS Info and Zone Transfer:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/DNSInfo" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No DNS data found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/dnsrecords.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='dnsrecords'>DNS Records:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/dnsrecords.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No DNS data found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/subdomains.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='subdomains'>Subdomains:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/subdomains.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No Subdomains found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/emails.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='emails'>Emails:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/emails.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No Emails found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/usernames.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='usernames'>Usernames:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/usernames.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No Usernames found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/squatting.csv" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='squatting'>Squatting:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/squatting.csv" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No Squatting found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/RegisteredDomainsSorted.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='registered_domains'>Registered Domains:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/RegisteredDomainsSorted.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No Registered Domains found.</p>" >> "DayOneScans/$domain/Report.html"
fi

if [ -r "DayOneScans/$domain/validusers.txt" ]; then
    echo "<section>" >> "DayOneScans/$domain/Report.html"
    echo "    <h2 id='valid_users'>Valid User Accounts:</h2>" >> "DayOneScans/$domain/Report.html"
    echo "    <pre>" >> "DayOneScans/$domain/Report.html"
    cat "DayOneScans/$domain/validusers.txt" >> "DayOneScans/$domain/Report.html"
    echo "    </pre>" >> "DayOneScans/$domain/Report.html"
    echo "</section>" >> "DayOneScans/$domain/Report.html"
else
    echo "    <p>No Valid Users found.</p>" >> "DayOneScans/$domain/Report.html"
fi

# Close the HTML file
echo "</body>" >> "DayOneScans/$domain/Report.html"
echo "</html>" >> "DayOneScans/$domain/Report.html"

# Print a completion message
echo "HTML report generated at DayOneScans/$domain/Report.html"

# Zip all files
echo " "
echo " "
echo " "
echo " "
echo "${GREEN}================== Zipping Files ==================${NC}"
# Define the zip filename
zip_filename="${domain}_OSINT.zip"

cd "DayOneScans/$domain"

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
