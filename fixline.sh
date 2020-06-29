#!/bin/bash

# run in background with this command
# nohup ./fixline.sh </dev/null &>/dev/null &

getWindows() {
  local focus
  local windows
  local items=$(xdotool search -classname "line.*.exe")
  for item in $items; do
    item=$(printf '0x%x' "$item")
    wmName=$(xprop -id "$item" WM_NAME)
    pat="\".*\""
    if [[ $wmName =~ $pat ]]; then
      mapState=$(xwininfo -id "$item" | grep "Map State")
      if [[ $mapState == *"IsViewable"* ]]; then
        windows="$windows $item"
        windows=$(echo "$windows" | xargs)
        wmState=$(xprop -id "$item" _NET_WM_STATE)
        if [[ $wmState == *"_NET_WM_STATE_FOCUSED"* ]]; then
          focus=$item
        fi
      fi
    fi
  done
  echo "$focus","$windows"
}
getBorders() {
  local skip="$2"
  local borders
  local address
  address=$(echo "$1" | xargs -n1 | sort -g | xargs)
  if [ -n "$address" ]; then
    for addr in $address; do
      if [ "$addr" != "$skip" ]; then
        edgeAndCorner=$((addr + 10))
        for ((i = edgeAndCorner; i < $((edgeAndCorner + 16)); i += 2)); do
          borders="$borders $i"
        done
      fi
    done
  fi
  echo "$borders"
}
showHide() {
  local all
  local show
  show=$(echo "$1" | sed -n "s/,.*$//p")
  all=$(echo "$1" | sed -n "s/^.*,//p")
  #clear
  if [ -n "$show" ]; then
    echo SHOW "$show"
    address="$(getBorders "$show")"
    for addr in $address; do
      xdotool windowmap "$addr" &
    done
  fi
  if [ -n "$all" ]; then
    echo ALL "$all"
    address="$(getBorders "$all" "$show")"
    for addr in $address; do
      xdotool windowunmap "$addr" &
    done
  fi
}

unset lastResult
# main loop
while true; do
  result=$(getWindows)
  if [ "$lastResult" != "$result" ]; then
    showHide "$result"
    lastResult="$result"
  fi
  #sleep 1 # lengthen process running
done
