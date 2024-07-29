#!/bin/bash

databases_dir="$(pwd)/databases"
mkdir -p "$databases_dir"

validate_name() {
    local name="$1"
    if [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        return 0
    else
        echo "Invalid name '$name'. Names must start with a letter and contain only letters, numbers, or underscores."
        return 1
    fi
}

validate_datatype() {
    local value="$1"
    local datatype="$2"
    case "$datatype" in
        int)
            if [[ "$value" =~ ^[0-9]+$ ]]; then
                return 0
            else
                return 1
            fi
            ;;
        string)
            if [[ "$value" =~ ^[a-zA-Z0-9[:space:][:punct:]]*$ ]]; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown datatype '$datatype'."
            return 1
            ;;
    esac
}

main_menu() {
    echo "Hello, welcome to database management system"
    echo "----Main Menu----"
    echo "1- Create Database"
    echo "2- List Databases"
    echo "3- Connect to Database"
    echo "4- Drop Database"
    echo "5- Exit"
    read -p "Please enter your choice: " choice
    case $choice in
        1) create_database ;;
        2) list_database ;;
        3) connect_database ;;
        4) drop_database ;;
        5) exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac        
}

create_database() {
    read -p "Enter database name: " dbname
    if ! validate_name "$dbname"; then
        return
    fi
    mkdir -p "$databases_dir/$dbname"
    echo "Database '$dbname' has been created."
    echo
}

list_database() {
    echo "Databases in $databases_dir are:"
    ls -1 "$databases_dir"
    echo
}

connect_database() {
    read -p "Enter database name to connect: " dbname
    if [ -d "$databases_dir/$dbname" ]; then
        cd "$databases_dir/$dbname" || { echo "Failed to change directory to '$databases_dir/$dbname'"; exit 1; }
        echo "Connected to database '$dbname'. Current directory: $(pwd)"
        database_menu
    else
        echo "Database '$dbname' does not exist."
    fi
}

drop_database() {
    read -p "Enter database name to drop: " dbname
    if [ -d "$databases_dir/$dbname" ]; then
        rm -rf "$databases_dir/$dbname"
        echo "Database '$dbname' dropped."
    else
        echo "Database '$dbname' does not exist."
    fi
}

database_menu() {
    echo "---->Database Menu<----"
    echo "1- Create Table"
    echo "2- List Tables"
    echo "3- Drop Table"
    echo "4- Insert into Table"
    echo "5- Select From Table"
    echo "6- Delete From Table"
    echo "7- Update Table"
    read -p "Please enter your choice: " choice
    case $choice in 
        1) create_table ;;
        2) list_tables ;;
        3) drop_table ;;
        4) insert_into_table ;;
        5) select_from_table ;;
        6) delete_from_table ;;
        7) update_table ;;
        *) echo "Invalid option" ;;
    esac
}

create_table(){
    read -p "Enter table name: " tablename

    # Validate table name
    if [[ ! "$tablename" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        echo "Invalid table name '$tablename'. Table names must start with a letter and contain only letters, numbers, or underscores."
        return
    fi

    if [ -f "$tablename.metadata" ]; then
        echo "'$tablename' already exists."
        return
    fi

    read -p "Enter number of fields (excluding 'id' field): " nf
    if ! [[ "$nf" =~ ^[0-9]+$ ]] || [ "$nf" -le 0 ]; then
        echo "Invalid number of fields."
        return
    fi

    echo "Define columns for table '$tablename'."
    columns=("id:int") # Ensure 'id' is always present and is of type int
    for ((i = 1; i <= nf; i++)); do
        while true; do
            read -p "Enter name for field $i: " col_name
            if [[ "$col_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
                break
            else
                echo "Invalid column name '$col_name'. Column names must start with a letter and contain only letters, numbers, or underscores."
            fi
        done

        while true; do
            read -p "Enter datatype for column '$col_name' (int, string): " col_type
            if [[ "$col_type" == "int" || "$col_type" == "string" ]]; then
                break
            else
                echo "Invalid datatype. Please enter 'int' or 'string'."
            fi
        done
        columns+=("$col_name:$col_type")
    done

    echo "Columns defined: ${columns[*]}"

    # Create the metadata file with the columns and primary key
    {
        IFS="|"; echo "${columns[*]}"
        echo "PRIMARY_KEY:id"
    } > "${tablename}.metadata"

    # Initialize the table file and ID tracking file
    touch "$tablename"
    echo "0" > "$tablename.id"

    echo "Table '$tablename' created with columns: ${columns[*]} and primary key: id"
}

list_tables() {
    echo
    echo "Tables:"
    ls -p | grep -v /
    echo
}

drop_table() {
    read -p "Enter table name to drop: " tablename
    if [ -f "$tablename" ]; then
        rm -f "$tablename"
        rm -f "$tablename.metadata"  # Remove metadata file
        rm -f "$tablename.id"  # Remove ID tracking file
        echo "'$tablename' dropped."
    else
        echo "'$tablename' does not exist."
    fi
}

insert_into_table() {
    read -p "Enter table name: " tablename
    if [ ! -f "$tablename" ]; then
        echo "Table '$tablename' does not exist."
        return
    fi

    IFS="|" read -r -a columns <<< "$(head -n 1 "$tablename.metadata")"
    primary_key=$(grep "PRIMARY_KEY" "$tablename.metadata" | cut -d: -f2)

    data=()
    for column in "${columns[@]}"; do
        col_name=$(echo "$column" | cut -d: -f1)
        col_type=$(echo "$column" | cut -d: -f2)

        while true; do
            if [ "$col_name" == "$primary_key" ]; then
                # Auto-generate unique ID for primary key
                if [ ! -f "$tablename.id" ]; then
                    echo "0" > "$tablename.id"
                fi
                next_id=$(($(cat "$tablename.id") + 1))
                echo "$next_id" > "$tablename.id"
                value="$next_id"
                break
            else
                read -p "Enter value for '$col_name' ($col_type): " value
                if validate_datatype "$value" "$col_type"; then
                    break
                else
                    echo "Invalid datatype for '$col_name'. Expected $col_type."
                fi
            fi
        done

        data+=("$value")
    done

    IFS="|"
    echo "${data[*]}" >> "$tablename"
    echo "Data inserted into table '$tablename'."
}

select_from_table() {
    echo "All tables in the current database:"
    ls -p | grep -v /

    read -p "Enter table name: " tablename
    if [ ! -f "$tablename" ]; then
        echo "Table '$tablename' does not exist."
        return
    fi

    IFS="|" read -r -a column_names <<< "$(head -n 1 "$tablename.metadata")"
    primary_key=$(grep "PRIMARY_KEY" "$tablename.metadata" | cut -d: -f2)

    echo "Available columns in table '$tablename':"
    for col in "${column_names[@]}"; do
        echo "$(echo $col | cut -d: -f1)"
    done

    read -p "Enter the columns to print (ex-->id:int (comma-separated): " columns

    IFS='|' read -r -a column_names <<< "$(head -n 1 "$tablename.metadata")"
    IFS=',' read -r -a selected_columns <<< "$columns"

    # Create a list of column indices
    column_indices=()
    for selected_column in "${selected_columns[@]}"; do
        found=0
        for i in "${!column_names[@]}"; do
            if [[ "${column_names[$i]}" == "$selected_column" ]]; then
                column_indices+=($((i + 1)))
                found=1
                break
            fi
        done
        if [ $found -eq 0 ]; then
            echo "Warning: Column '$selected_column' not found in table."
        fi
    done

    if [ ${#column_indices[@]} -eq 0 ]; then
        echo "No valid columns selected."
        return
    fi

    # Convert column indices array to a string that can be used in awk
    indices=$(IFS=','; echo "${column_indices[*]}")

    echo "Selected columns from table '$tablename':"
    awk -F "|" -v indices="$indices" '
    BEGIN {
        split(indices, idxs, ",")
        for (i in idxs) {
            cols[i] = idxs[i]
        }
        OFS = FS
    }
    {
        for (i = 1; i <= length(cols); i++) {
            printf "%s%s", $cols[i], (i == length(cols) ? ORS : OFS)
        }
    }' "$tablename"
}

delete_from_table() {
    read -p "Enter table name: " tablename
    if [ ! -f "$tablename" ]; then
        echo "Table '$tablename' does not exist."
        return
    fi
    echo "Contents of table '$tablename':"
    cat "$tablename"
    read -p "Enter row number to delete: " row_num

    sed -i "${row_num}d" "$tablename"
    echo "Row $row_num deleted from table '$tablename'."
}

update_table() {
    read -p "Enter table name: " tablename
    if [ ! -f "$tablename" ]; then
        echo "Table '$tablename' does not exist."
        return
    fi

    echo "Contents of table '$tablename':"
    cat "$tablename"
    read -p "Enter row number to update: " row_num

    IFS="|" read -r -a columns <<< "$(head -n 1 "$tablename.metadata")"
    primary_key=$(grep "PRIMARY_KEY" "$tablename.metadata" | cut -d: -f2)
    data=()
    for column in "${columns[@]}"; do
        col_name=$(echo "$column" | cut -d: -f1)
        col_type=$(echo "$column" | cut -d: -f2)

        while true; do
            read -p "Enter new value for '$col_name' ($col_type): " value
            if validate_datatype "$value" "$col_type"; then
                if [ "$col_name" == "$primary_key" ]; then
                    existing_value=$(sed -n "${row_num}p" "$tablename" | cut -d'|' -f$(( $(echo "${columns[*]}" | tr ' ' '\n' | grep -n "^$col_name:" | cut -d: -f1) )))
                    if [ "$value" != "$existing_value" ] && grep -q "|$value|" "$tablename"; then
                        echo "Error: Duplicate value for primary key '$col_name'."
                        continue
                    fi
                fi
                data+=("$value")
                break
            else
                echo "Invalid datatype for '$col_name'. Expected $col_type."
            fi
        done
    done

    new_data=$(IFS="|" echo "${data[*]}")
    sed -i "${row_num}s/.*/$new_data/" "$tablename"
    echo "Row $row_num updated in table '$tablename'."
}

# Start the main menu loop
while true; do
    main_menu
done

