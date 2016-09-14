#!/usr/bin/env python
import pandas as pd
data = pd.io.stata.read_stata('geo_cepii.dta')
data.to_csv('geo_cepii.csv')
data = pd.io.stata.read_stata('dist_cepii.dta')
data.to_csv('dist_cepii.csv')
