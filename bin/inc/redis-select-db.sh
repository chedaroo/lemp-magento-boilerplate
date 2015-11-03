#!/usr/bin/env bash

redis_select_db () {
        unset get_db
        unset existing_dbs

        local db_description=$1

        declare -a existing_dbs

        style_line cyan bold "Redis $db_description"
        style_line "Please enter the keyspace of the Redis Database you wish to use for the $db_description's below."
        style_line "The keyspace should be in the form of an integer, such as '1'."
        style_message hint "It is advisable not to use an already active keyspace as this may cause abnormal evections."
        style_message hint "You can type 'list' to see currently active database"
        style_line "Redis keyspace to use:"

        while [[ ! ${get_db} =~ ^[0-9]+$ ]]; do

                read get_db
                printf "\n"

                if [ "${get_db}" == "list" ]; then
                        redis_keyspaces=$(redis-cli INFO keyspace)
                        echo "${redis_keyspaces}"
                        printf "\n"
                        unset get_db
                fi

                existing_dbs=($(redis-cli INFO | grep ^db | sed -r 's/db([0-9]*)..*/\1/g'))

                if in_array existing_dbs "${get_db}"; then
                        style_message warn "Redis db${get_db} is already in use!"
                        style_line "Sharing databases is not advisable and may cause abnormal evictions."
                        style_line "If you are sure you want to do this type 'YES' to confirm, otherwise hit any key to abort and select a different keyspace."
                        read db_confirm

                        if [ "$db_confirm" != "YES" ]; then
                                printf "Aborted\n"
                                unset get_db
                        else
                                printf "\n"
                                style_line green "Redis database ${get_db} has been selected."
                        fi

                        printf "\n"
                        unset existing_dbs
                fi
        done
}
