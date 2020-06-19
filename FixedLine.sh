#!/bin/bash

while true ; do
    unset shows
    unset hides
    items1=$(xdotool search -class "line.exe")
    items2=$(xdotool search -class "linemediaplayer.exe")
    items=$(echo $items1 $items2)
    for item in $items
    do
        wmName=$(xprop -id "$item" WM_NAME)
        pat="\".*\""
        if [[ $wmName =~ $pat ]]
        then
            #echo "$item": $wmName
            mapState=$(xwininfo -id "$item" | grep "Map State")
            if [[ $mapState == *"IsViewable"* ]]
            then
                #echo "$item": "$wmName", "$mapState"
                #xprop -spy -id $item _NET_WM_STATE &
                wmState=$(xprop -id "$item" _NET_WM_STATE)
                if [[ $wmState == *"_NET_WM_STATE_FOCUSED"* ]]
                then
                    shows=$(echo "$shows" "$item")
                else
                    hides=$(echo "$hides" "$item")
                fi
            fi
        fi
    done
    if [ "$lastShows" != "$shows" ]
    then
        if [ -n "$shows" ]
        then
            echo SHOWS \("$shows" \)
            unset borders
            edge=$(($shows+10))
            for ((i=$edge; i<$(($edge+16)); i+=2))
            do
                borders=$(echo $borders $i)
            done
            #echo SHOWING BORDERS "$borders"
            for border in $borders
            do
                xdotool windowmap $border
            done
        fi
        lastShows=$shows
    fi
    if [ "$lastHides" != "$hides" ]
    then
        echo HIDES \("$hides" \)
        unset borders
        for item in $hides
        do
            edge=$(($item+10))
            for ((i=$edge; i<$(($edge+16)); i+=2))
            do
                borders=$(echo $borders $i)
            done
            for border in $borders
            do
                xdotool windowunmap $border
                #echo "$border"
            done
        done
        lastHides=$hides
    fi
    sleep 1
done
