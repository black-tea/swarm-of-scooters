# Swarm of Scooters
![screenshot] 
This web map shows the current location of all available dockless devices available for select cities. This map was constructed using R's Shiny Library.

#### TODO  
- [x] Fix color for Spin
- [x] Spin LA URL
- [x] Add Bird GBFS feeds
- [x] Add total device count
- [x] Fix temporary company filter holdover
- [ ] Add Santa Monica for Lime (where is the gbfs feed???)
- [x] Combine Arlington w/ DC
- [x] Make sure initial city selected is Los Angeles
- [ ] Project write-up
- [ ] DC Neighborhood Map: http://data.codefordc.org/dataset/neighborhood-boundaries-217-neighborhoods-washpost-justgrimes
- [ ] Denver Neighborhood Map: https://www.denvergov.org/opendata/dataset/city-and-county-of-denver-statistical-neighborhoods
- [ ] San Diego Communities: http://sangis.org/docs/news/Layer_Update_Report.pdf
- [ ] SF Neighborhood Map: https://data.sfgov.org/Geographic-Locations-and-Boundaries/SF-Find-Neighborhoods/pty2-tcw4
- [ ] NYC Boroughs: https://data.cityofnewyork.us/City-Government/Borough-Boundaries/tqmj-j8zm
- [ ] LA Neighborhoods outside city boundaries?
- [x] Move to shinyapps.io
- [x] Fix issue: Cities w/out bikes
- [x] Move hex colors to `data` and import into app
- [x] Add Wheels & Skip to map


#### GBFS Feeds
These data are made publicly available by dockless mobility companies either voluntarily or as required by municipalities for a permit to operate. They are formatted according to the [General Bikeshare Feed Specification (GBFS)](https://github.com/NABSA/gbfs) that is maintained by the [North American Bike Share Association (NABSA)](https://nabsa.net/). Although GBFS was originally designed for docked bikeshare, it can be adapted fairly easily to cover the broader category of dockless devices as well.  

The table in `data/systems.csv` lists all the GBFS feeds for dockless mobility companies that I currently have. In many cases, I was able to get data from NABSA's [`systems.csv`](https://github.com/NABSA/gbfs/blob/master/systems.csv). However, in other cases I was able to find publicly-available feeds that were not listed on that list. For example, Bird does not post any of their system information there. 

#### Map Styling
The following table includes the color that I used to symbolize the provider in the map. I will update the table (and map) as I add any new providers.

| Provider |   Icon    |   Hex   |
|:--------:|:---------:|:-------:|
| Bird     | ![bird]   | #000000 |
| HOPR     | ![hopr]   | #5DBCD2 |
| JUMP     | ![jump]   | #F36396 |
| Lime     | ![lime]   | #24D000 |
| Lyft     | ![lyft]   | #4F1397 |
| Razor    | ![razor]  | #FF0000 |
| Skip     | ![skip]   | #FCCE24 |                                                                                          
| Spin     | ![spin]   | #FF5503 |
| Wheels   | ![wheels] | #3D4CB7 |
| Wind     | ![wind]   | #5E7C8B |

#### Neighborhoods
Zooming out on the map will triggers neighborhood polygon overlays with devices counts for each.

[bird]: www/bird_circle2.png
[hopr]: www/cyclehop_circle.png
[jump]: www/jump_circle.png
[lime]: www/lime_circle.png
[lyft]: www/lyft_circle.png
[razor]: www/razor_circle.png
[skip]: www/skip_circle.png
[spin]: www/spin_circle.png
[wind]: www/wind_circle.png
[wheels]: www/wheels_circle.png

[screenshot]: www/screenshot.PNG

### Forking
[Kevin Amézaga](https://mostlikelykevin.com) forked this project to add Miami's scooter vendors as a part of the [Miami Riders Alliance's](https://riders.miami) campaign, the [Mobile Miami Coalition](https://coalition.miami)
