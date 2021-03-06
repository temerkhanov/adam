#!/bin/sh
# 
# This script assumes that we're running together with EVE services
# and thus have access to the following folders:
#    /config  - containing all the usual EVE configuration files, to wit:
#      * /config/root-certificate.pem (getting replaced by Adam's cert)
#      * /config/server (getting replaced by Adam's local URL)
#      * /config/device.cert.pem (Adam waits for it to show up so it can be registered)
#    /persist - a persistent storage medium where we can keep our state
set -x

PORT=6000
STORE=${STORE:-/persist/adam}
DB=${DB:-redis://}

SERVER=localhost:$PORT
SERVER_URL=https://$SERVER

bootstrap() {
   ADAM_CMD="adam admin --server $SERVER_URL --server-ca $STORE/server.pem"
   # first make sure to register ourselves, skipping onboarding step
   #   adam admin onboard add  --path /config/onboard.cert.pem --serial '*'
   while true; do
      sleep 10
      if [ -f /config/device.cert.pem ]; then
         $ADAM_CMD device add --path /config/device.cert.pem && break
      fi
   done

   # then lets see what should be our default config
   cp /config/adam.json /adam/default.json || cp /adam/simple.json /adam/default.json
   if [ $(wc -l < /config/authorized_keys) -eq 1 ]; then
      sed -ie 's#@EVE_SSH_KEY@#'"$(cat /config/authorized_keys)"'#' /adam/default.json
   fi
   UUID=$($ADAM_CMD device list | head -1)
   if [ -n "$UUID" ]; then
      $ADAM_CMD device config set --uuid $UUID --config-path /adam/default.json
   fi
}

# if this is the first run on this /persist -- generate everything
if [ ! -d "$STORE" ]; then
   adam generate --db-url "$STORE" --server --hosts 127.0.0.1,localhost --cn localhost
   bootstrap &
fi

adam server --port $PORT --db-url $DB --conf-dir /config --server-cert "$STORE/server.pem" --server-key "$STORE/server-key.pem"
