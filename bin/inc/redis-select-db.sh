#!/usr/bin/env bash

redis_select_db () {
        unset get_db
        unset existing_dbs

        declare -a existing_dbs

        while [[ ! ${get_db} =~ ^[0-9]+$ ]]; do

                printf "Please enter the keyspace of the Redis Database you wish to use below.\n"
                printf "The keyspace should be in the form of an integer, such as '1'.\n"
                printf "\n[HINT] It is advisable not to use an already active keyspace as this may cause abnormal evections.\n"
                printf "You can type 'list' to see currently active database\n"
                printf "\nRedis keyspace to use:\n"
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
                        printf "WARNING: Redis db${get_db} is already in use!\n"
                        printf "Sharing databases is not advisable and may cause abnormal evictions.\n"
                        printf "If you are sure you want to do this type 'YES' to confirm, otherwise hit any key to abort and select a different keyspace.\n"
                        read db_confirm

                        if [ "$db_confirm" != "YES" ]; then
                                printf "Aborted\n"
                                unset get_db
                        else
                                printf "\n"
                                printf "Redis database ${get_db} has been selected."
                        fi

                        printf "\n"
                        unset existing_dbs
                fi
        done
}
