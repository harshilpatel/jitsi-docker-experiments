server_names_hash_bucket_size 64;

server {
    listen 443;
    # tls configuration that is not covered in this guide
    # we recommend the use of https://certbot.eff.org/
    server_name jitsi.example.com;
    # set the root
    root /srv/jitsi.example.com;
    index index.html;
    location ~ ^/([a-zA-Z0-9=\?]+)$ {
        rewrite ^/(.*)$ / break;
    }
    location / {
        ssi on;
    }
    # BOSH
    location /http-bind {
        proxy_pass      http://localhost:5280/http-bind;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Host $http_host;
    }
}