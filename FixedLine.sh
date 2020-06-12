#!/bin/sh

items=`xdotool search -class "line.exe"`

isFocuses=0
for item in $items
do
  wmState=`xprop -id $item _NET_WM_STATE`
  if [[ $wmState == *"_NET_WM_STATE_FOCUSED"* ]]
  then
    echo $item: $wmState
    isFocuses=1
    break
  fi
done

for item in $items
do
  widthGrep=`xwininfo -id $item | grep -e "Width:"`
  widths=`echo $widthGrep | sed "s/^Width: \(.*\)$/\1/"`
  for width in $widths
  do
    if [ $width -eq 11 ]
    then
      if [ $isFocuses -eq 1 ]
      then
        xdotool windowmap $item
      else
        xdotool windowunmap $item
      fi
    fi
  done
  
  heightGrep=`xwininfo -id $item | grep -e "Height:"`
  heights=`echo $heightGrep | sed "s/^Height: \(.*\)$/\1/"`
  for height in $heights
  do
    if [ $heights -eq 11 ]
    then
      if [ $isFocuses -eq 1 ]
      then
        xdotool windowmap $item
      else
        xdotool windowunmap $item
      fi
    fi
  done
done
