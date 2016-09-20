#!/usr/bin/env python
import pandas as pd
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-g", "--geo-cepii",
                        help="a geo-cepii file in DTA format",
                        default="geo_cepii.dta")
parser.add_argument("-d", "--dist-cepii",
                        help="a dist-cepii file in DTA format",
                        default="dist_cepii.dta")
parser.add_argument("-b", "--geoip-block-ipv4",
                        help="GeoIP IPv4 Blocks in CSV format",
                        default="GeoLite2-Country-Blocks-IPv4.csv")
parser.add_argument("-c", "--geoip-block-ipv6",
                        help="GeoIP IPv6 Blocks in CSV format",
                        default="GeoLite2-Country-Blocks-IPv6.csv")
parser.add_argument("-l", "--geoip-locations",
                        help="GeoIP Location names in CSV format",
                        default="GeoLite2-Country-Locations-en.csv")
parser.add_argument("-o", "--output",
                        help="file to write output to",
                        default="geoip.lst")
args = parser.parse_args()
# Reading in all the files
# TODO: Add these as arguments instead
# Collected from cepii.fr, hidden behind login, but free.
geo = pd.io.stata.read_stata(args.geo_cepii)
dist = pd.io.stata.read_stata(args.dist_cepii)
# Collected from Maxmind
# This product includes GeoLite2 data created by MaxMind, available from
# <a href="http://www.maxmind.com">http://www.maxmind.com</a>.
# http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country-CSV.zip
blocks_ipv4 = pd.read_csv(args.geoip_block_ipv4)
blocks_ipv6 = pd.read_csv(args.geoip_block_ipv6)
blocks = pd.concat([blocks_ipv4,blocks_ipv6])
loc = pd.read_csv(args.geoip_locations)

# http://pandas.pydata.org/pandas-docs/stable/generated/pandas.DataFrame.set_index.html
# Setting up proper indexes so it's possible to merge the data
blocks.set_index('geoname_id')
loc.set_index('geoname_id')
geo.set_index(['iso2','iso3'])
dist.set_index(['iso_o','iso_d'])

# Now we want to merge the GeoIP databases to get a complete set.
# Note that country_iso_code is missing for EU and US.
# We fix this by using continent_code and then fillna solves it for us!
# This helps alot http://pandas.pydata.org/pandas-docs/stable/merging.html
# http://pandas.pydata.org/pandas-docs/stable/generated/pandas.DataFrame.rename.html
loc = loc.loc[:,['geoname_id','continent_code','country_iso_code']].rename(columns={'country_iso_code':'iso2'})
geo = geo.loc[:,['iso2','iso3']]
blocks = blocks.loc[:,['network','geoname_id']]
networks = (
             blocks.merge(loc).merge(geo).drop_duplicates()
           )
networks.iso2 = networks.iso2.fillna(value=networks.continent_code)
networks.drop('continent_code',axis=1, inplace=True)

# Our own mirrors, converted to iso3 format.
mirrors = [x.upper() for x in ("de","se","cz","au","hk","fr","us","gb")]
# http://pandas.pydata.org/pandas-docs/stable/generated/pandas.DataFrame.drop_duplicates.html
mirrors_iso3 = (
                 geo.query('iso2 == @mirrors')
                 .drop_duplicates()
                 .to_dict(orient='list')['iso3']
               )

# Figure out the closest mirror by sorting distance.
# We retrieve the indexes for those rows and use them later
indexes = [] 
for origin in dist.iso_o.unique():
 indexes.append((
                  dist.query('(iso_o == @origin) and (iso_d == @mirrors_iso3)')
                  .sort_values(by='dist')
                  .index[0]
                ))

# Fethching the dist-data with indexes and preparing it for a merge
backend_selection = (
                      dist.loc[indexes].loc[:,['iso_o','iso_d']]
                      .rename(columns={'iso_o':'iso3', 'iso_d':'backend_iso3'})
                    )
backend_selection.set_index(['iso3'])

# Merging with geo-data to get the iso2 names
geo = geo.loc[:,['iso2','iso3']].rename(columns={'iso3':'backend_iso3','iso2':'backend'}).replace('GB','UK')
backend_selection = backend_selection.merge(geo)

# Join in backend_selection with networks to complete our set
networks = networks.merge(backend_selection).loc[:,['network','backend']].drop_duplicates()

# Just print it out in a nice format for HAProxy to read.
f = open('geoip.lst', 'w')
for index, rows in networks.iterrows():
  f.write('{} {:2}\n'.format(rows['network'], rows['backend']))
f.close()
