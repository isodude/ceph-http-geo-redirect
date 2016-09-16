#!/usr/bin/env python
import pandas as pd
geo = pd.io.stata.read_stata('geo_cepii.dta')
dist = pd.io.stata.read_stata('dist_cepii.dta')
blocks_ipv4 = pd.read_csv('GeoLite2-Country-CSV_20160802/GeoLite2-Country-Blocks-IPv4.csv')
blocks_ipv6 = pd.read_csv('GeoLite2-Country-CSV_20160802/GeoLite2-Country-Blocks-IPv4.csv')
loc = pd.read_csv('GeoLite2-Country-CSV_20160802/GeoLite2-Country-Locations-en.csv')
blocks = pd.concat([blocks_ipv4,blocks_ipv6])
# http://pandas.pydata.org/pandas-docs/stable/generated/pandas.DataFrame.set_index.html
blocks.set_index('geoname_id')
loc.set_index('geoname_id')
geo.set_index(['iso2','iso3'])
dist.set_index(['iso_o','iso_d'])

def iso2_to_iso3(iso2):
 return geo.query('iso2 == @iso2').iloc[0]['iso3']

def iso3_to_iso2(iso3):
 return geo.query('iso3 == @iso3').iloc[0]['iso2']

def geoname_id_to_iso2(geoname_id):
 return loc.query('loc.geoname_id == @geoname_id').iloc[0]['country_iso_code']

mirrors = [x.upper() for x in ("de","se","cz","au","hk","fr","us")]
# http://pandas.pydata.org/pandas-docs/stable/generated/pandas.DataFrame.drop_duplicates.html
mirrors_iso3 = geo.query('iso2 == @mirrors').drop_duplicates().to_dict(orient='list')['iso3']

indexes = [] 
for origin in dist.iso_o.unique():
 indexes.append(dist.query('(iso_o == @origin) and (iso_d == @mirrors_iso3)').sort_values(by='dist').index[0])

backend_selection = dist.loc[indexes].loc[:,['iso_o','iso_d']]
backend_selection.rename(columns={'iso_o':'iso3', 'iso_d':'backend_iso3'}, inplace=True)
backend_selection.set_index(['iso3'])
backend_selection = backend_selection.merge(geo.loc[:,['iso2','iso3']].rename(columns={'iso2':'backend','iso3':'backend_iso3'})) 

# this helps alot http://pandas.pydata.org/pandas-docs/stable/merging.html
networks = blocks.merge(loc).loc[:,['network','continent_code','country_iso_code']]
# http://pandas.pydata.org/pandas-docs/stable/generated/pandas.DataFrame.rename.html
networks.rename(columns={'country_iso_code':'iso2'}, inplace=True)
networks.iso2 = networks.iso2.fillna(value=networks.continent_code)
networks.drop('continent_code',axis=1, inplace=True)
networks = networks.merge(geo.loc[:,['iso2','iso3']])
networks = networks.merge(backend_selection)
networks.loc[:,['network','backend']].to_csv('geoip.csv')
