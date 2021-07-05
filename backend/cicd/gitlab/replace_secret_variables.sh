sed -i "s/__DB_CONN_STRING__/$APP_DB_CONN_STRING/" cicd/config/$1.config_api.sh
sed -i "s/__JWT__/$JWT_KEY/" cicd/config/$1.config_api.sh