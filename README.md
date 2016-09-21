# ceph-http-geo-redirect
A project that will redirect requests towards download.ceph.com towards their regional mirror.

# Try it out
`git clone http://github.com/isodude/ceph-http-geo-redirect`
First of all, you need to download the proper files, it' documented in generate_geoip_lst.py.
`pip install pandas`
`./generate_geoip_lst.py`
`./generate_haproxy_config.sh`
`docker-compose up`
