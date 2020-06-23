#!/bin/bash

#nohup ./fixline.sh </dev/null &>/dev/null &
# main loop
while true
do
    # find active windows
    # input null
    # output ($show, $windows)
    getWindows() {
        unset show
        unset windows
        items=$(xdotool search -class "line.*.exe")
        for item in $items
        do
            #echo xprop -id  "$item" WM_NAME
            wmName=$(xprop -id "$item" WM_NAME)
            pat="\".*\""
            if [[ $wmName =~ $pat ]]
            then
                mapState=$(xwininfo -id "$item" | grep "Map State")
                if [[ $mapState == *"IsViewable"* ]]
                then
                    #xprop -spy -id $item _NET_WM_STATE &
                    windows="$windows $item"
                    windows=$(echo "$windows" | xargs)
                    wmState=$(xprop -id "$item" _NET_WM_STATE)
                    if [[ $wmState == *"_NET_WM_STATE_FOCUSED"* ]]
                    then
                        show="$item"
                        #showName=$(echo "$showName" $(echo "$wmName" | grep -oP \".*\"))
                    fi
                fi
            fi
        done
    }
    
    # collect all edges and corners
    # input ($address, $skip)
    # output ($border)
    getBorders() {
        unset borders
        #echo ADDRESS\($address\)
        address=$(echo "$address" | xargs -n1 | sort -g | xargs)
        if [ -n "$address" ]
        then
            #echo SKIP $skip
            for addr in $address
            do
                if [ "$addr" != "$skip" ]
                then
                    edgeAndCorner=$((addr+10))
                    for ((i=edgeAndCorner; i<$((edgeAndCorner+16)); i+=2))
                    do
                        borders="$borders $i"
                    done
                fi
            done
        fi
        echo "$borders"
    }
    
    # on changed
    onChanged() {
        unset addressHide
        unset addressShow
        if [ "$_show" != "$show" ]
        then
            if [ -z "$show" ]
            then
                addressHide=$_show
            else
                if [ -n "$_show" ]
                then
                    addressHide=$_show
                fi
                addressShow=$show
            fi
            _show=$show
        fi
    }
    
    doShowOrHide() {
        if [ -n "$addressHide" ]
        then
            echo HIDE ALL
            address=$windows
            hideBorders=$(getBorders)
            if [ -n "$hideBorders" ]
            then
                for border in $hideBorders
                do
                    xdotool windowunmap "$border" &
                done
            fi
        fi
        if [ -n "$addressShow" ]
        then
            echo HIDE SOMES
            local skip
            address=$windows
            skip=$addressShow
            hideBorders=$(getBorders)
            if [ -n "$hideBorders" ]
            then
                for border in $hideBorders
                do
                    xdotool windowunmap "$border" &
                done
            fi
            
            unset skip
            echo SHOW "$addressShow"
            address=$addressShow
            showBorders=$(getBorders)
            if [ -n "$showBorders" ]
            then
                for border in $showBorders
                do
                    xdotool windowmap "$border" &
                done
            fi
        fi
    }
    
    getWindows
    onChanged
    doShowOrHide
    sleep .1   # untight process running
done
