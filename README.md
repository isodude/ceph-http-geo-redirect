# ceph-http-geo-redirect
A project that will redirect requests to download.ceph.com towards their regional mirror.
It uses databases from Maxmind and dist.fr to route accordingly.

Currently it uses a python script (depending on Pandas) to generate the ip list.
Another script generates a haproxy config.

# Try it out
```
git clone https://github.com/isodude/ceph-http-geo-redirect && \
cd ceph-http-geo-redirect && \
sudo apt update && \
sudo apt -y install python-pandas unzip haproxy && \
sudo curl -O http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country-CSV.zip && \
curl -O http://www.cepii.fr/distance/geo_cepii.dta && \
curl -O http://www.cepii.fr/distance/dist_cepii.dta && \
unzip GeoLite2-Country-CSV.zip && \
rm GeoLite2-Country-CSV.zip && \
mv GeoLite2-Country-CSV_*/GeoLite2-Country-Blocks-IPv* . && \
mv GeoLite2-Country-CSV_*/GeoLite2-Country-Locations-en.csv . && \
rm -rf GeoLite2-Country-CSV_* && \
./generate_geoip_lst.py && \
./generate_haproxy_config.sh && \
sudo ln -fs /etc/haproxy/haproxy.cfg $PWD/haproxy.cfg && \
sudo mv haproxy.cfg /etc/haproxy/haproxy.cfg && \
sudo service haproxy restart
```

Implementing Let's Encrypt would be something in the following fashion
```
fqdn=$(hostname -f)
email="email@example.com"
certbot certonly --rsa-key-size 4096 --config-dir $HOME/tmp/config --work-dir $HOME/tmp/work --logs-dir $HOME/tmp/logs -m $email --standalone --agree-tos --preferred-challenges http-01 --http-01-port 54321 -d $fqdn
cat $HOME/tmp/config/archive/$fqdn/privkey1.pem $HOME/tmp/config/archive/$fqdn/fullchain1.pem | sudo tee /etc/ssl/certs/$fqdn.cert.pem
service haproxy restart
```

Renewal
```
fqdn=$(hostname -f)
email="email@example.com"
certbot renew --rsa-key-size 4096 --config-dir $HOME/tmp/config --work-dir $HOME/tmp/work --logs-dir $HOME/tmp/logs -m $email  --standalone  --agree-tos --preferred-challenges http-01 --http-01-port 54321
cat $HOME/tmp/config/archive/$fqdn/privkey1.pem $HOME/tmp/config/archive/$fqdn/fullchain1.pem | sudo tee /etc/ssl/certs/$fqdn.pem
service haproxy restart
```
