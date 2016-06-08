#!/bin/bash

# Change this to scrape a different line-up
LIST=$(curl -s http://fielddayfestivals.com/line-up/ | pup '.artist text{}')

[ -f secrets.json ] || echo "secrets.json file not found!" && exit 1

TOKEN=$(cat secrets.json | jq .token)
PLAYLISTNAME=$(cat secrets.json | jq .playlistName)
USERNAME=$(cat secrets.json | jq .userName)

[ -z "$TOKEN" || -z "$PLAYLISTNAME" || -z "$USERNAME" ] && echo 'Cannot read secrets file. Missing token, playlistName or userName' && exit 1

PLAYLISTID=$(curl -X POST "https://api.spotify.com/v1/users/$USERNAME/playlists" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data "{\"name\":\"$PLAYLISTNAME\",\"public\":false}" | jq .id) && echo "$PLAYLISTID" || echo "There was a problem creating the playlist" && exit 1

echo "$LIST" | while read artist; do
  echo "Getting: $artist"
  enc=$(echo "$artist" | xxd -plain | tr -d '\n' | gsed 's/\(..\)/%\1/g')
  artid=$(curl -X GET "https://api.spotify.com/v1/search?q=$enc&type=artist&limit=1" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" | jq '.artists.items[0].id' | sed 's/"//g')
  echo "Artist id: $artid"
  toptracks=$(curl -X GET "https://api.spotify.com/v1/artists/$artid/top-tracks?country=GB" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN")
  toptracksids=$(echo "$toptracks" | jq '.tracks[].id' | sed 's/"//g')
  toptracksnames=$(echo "$toptracks" | jq '.tracks[].name')
  echo "Adding: $toptracksnames"
  toptracksidsenc=$(echo "$toptracksids" | awk '{printf "spotify:track:"$0","}')
  echo "Top tracks encoded: $toptracksidsenc"
  curl -X POST "https://api.spotify.com/v1/users/$USERNAME/playlists/0JnJHUSl9jkwJfvbIMUQyS/tracks?uris=$toptracksidsenc" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN"
  sleep 2
done
