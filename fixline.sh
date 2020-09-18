#!/bin/bash

#nohup ./fixline.sh </dev/null &>/dev/null &
# main loop
while true
do
    # find active windows
    # input ($lIds, $lmIds)
    # output ($show, $windows)
    getWindows() {
        unset show
        unset windows
        #items="${lIds[*]} ${lmIds[*]}"
        pid=$(pgrep LINE.exe)
        if [ -z "$pid" ]
        then
            return 1
        else
            item1=$(xdotool search --pid "$pid" --sync)
            unset item2
            pids=($(pgrep linemediaplayer))
            if [ ${#pids[@]} -ge "3" ]
            then
                for pid in "${pids[@]}"
                do
                    wids=($(xdotool search --pid "$pid" --sync))
                    if [ ${#wids[@]} -gt "2" ]
                    then
                        #echo "Has Viewer id: $(echo "obase=16; ${wids[2]}" | bc)"
                        item2=$(echo "$item2 ${wids[@]}" | xargs)
                    fi
                done
            fi
            items=$(echo "$item1 $item2" | xargs)
            for item in $items
            do
                xwininfo -id "$item" > /tmp/xWinInfo & wait $!
                if [ $? -eq "1" ]
                then
                    break
                fi
                xWinInfo=$(cat /tmp/xWinInfo)
                mapState=$(echo "$xWinInfo" | grep "Map State")
                if [[ $mapState == *"IsViewable"* ]]
                then
                    #xprop -spy -id $item _NET_WM_STATE &
                    windows=$(echo "$windows $item" | xargs)
                    wmState=$(xprop -id "$item" _NET_WM_STATE)
                    if [[ $wmState == *"_NET_WM_STATE_FOCUSED"* ]]
                    then
                        show="$item"
                    fi
                fi
            done
        fi
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
                    if [[ $item2 == *$addr* ]]
                    then
                        #linemediaplayer
                        edgeAndCorner=$((addr+14))
                    else
                        #LINE.exe
                        edgeAndCorner=$((addr+10))
                    fi
                    for ((i=edgeAndCorner; i<$((edgeAndCorner+16)); i+=2))
                    do
                        borders=$(echo "$borders $i" | xargs)
                    done
                fi
            done
            echo $borders
        fi
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
                    xdotool windowunmap "$border" & wait $!
                    if [ $? -eq "1" ]
                    then
                        break
                    fi
                done
            fi
        fi
        if [ -n "$addressShow" ]
        then
            echo HIDE SOMES
            address=$windows
            skip=$addressShow
            hideBorders=$(getBorders)
            if [ -n "$hideBorders" ]
            then
                for border in $hideBorders
                do
                    xdotool windowunmap "$border" & wait $!
                    if [ $? -eq "1" ]
                    then
                        break
                    fi
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
                    xdotool windowmap "$border" & wait $!
                    if [ $? -eq "1" ]
                    then
                        break
                    fi
                done
            fi
        fi
    }
    getWindows
    if [ $? -eq "1" ]
    then
        echo "No process LINE.exe running found!"
        sleep 3
    else
        onChanged
        doShowOrHide
        sleep .5   # untight process running
    fi
done
