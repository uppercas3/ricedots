#! /bin/sh
#

# Absorb all of the rote variable setting to make our panel self-contained

# From example .profile changes

PANEL_FIFO="$HOME/.config/bspwm/panfifo"
PANEL_HEIGHT="16"
PANEL_FONT_FAMILY="-*-terminus-medium-r-normal-*-12-*-*-*-c-*-*-1"

# From panel_colors file

COLOR_FOREGROUND='#A3A6AB'
COLOR_BACKGROUND='#34322E'
COLOR_ACTIVE_MONITOR_FG='#34322E'
COLOR_ACTIVE_MONITOR_BG='#58C5F1'
COLOR_INACTIVE_MONITOR_FG='#58C5F1'
COLOR_INACTIVE_MONITOR_BG='#34322E'
COLOR_FOCUSED_OCCUPIED_FG='#F6F9FF'
COLOR_FOCUSED_OCCUPIED_BG='#5C5955'
COLOR_FOCUSED_FREE_FG='#F6F9FF'
COLOR_FOCUSED_FREE_BG='#6D561C'
COLOR_FOCUSED_URGENT_FG='#34322E'
COLOR_FOCUSED_URGENT_BG='#F9A299'
COLOR_OCCUPIED_FG='#A3A6AB'
COLOR_OCCUPIED_BG='#34322E'
COLOR_FREE_FG='#6F7277'
COLOR_FREE_BG='#34322E'
COLOR_URGENT_FG='#F9A299'
COLOR_URGENT_BG='#34322E'
COLOR_LAYOUT_FG='#A3A6AB'
COLOR_LAYOUT_BG='#34322E'
COLOR_TITLE_FG='#A3A6AB'
COLOR_TITLE_BG='#34322E'
COLOR_STATUS_FG='#A3A6AB'
COLOR_STATUS_BG='#34322E'

# Kill any panel processes older than us, instead of bailing like the example
# does. That caused one too many panel-less boots for me.

while [ $(pgrep -cx panel) -gt 1 ] ; do
	pkill -ox -9 panel
done

# Kill any remaining trays / xtitle instances so we don't have multiples.

killall -9 stalonetray
killall -9 xtitle

# Setup taken from example, tell bspwm to avoid our status/tray and to start
# sending status updates to a FIFO

trap 'trap - TERM; kill 0' INT TERM QUIT EXIT

[ -e "$PANEL_FIFO" ] && rm "$PANEL_FIFO"
mkfifo "$PANEL_FIFO"

bspc config top_padding $PANEL_HEIGHT
bspc control --subscribe > "$PANEL_FIFO" &

# Here are the subprograms that add information to the status FIFO which are
# interpreted by panel_bar, below. Each output is detected by its first
# character, which is how the bspwm internal information is presented.

# T - xtitle output
# S - date output (same as example)
# B - battery output

# Title

xtitle -sf 'T%s' > "$PANEL_FIFO" &

# Simple date

function clock {
    while true; do
        date +"S%d/%m %H:%M:%S"
        sleep 1
    done
}

clock > "$PANEL_FIFO" &

# No frills battery monitor (Linux specific, probably)
# This is only enabled on certain hostnames, at the end of this file.

BAT="/sys/class/power_supply/BAT0"

function bat_percent {
    while true; do
        CHARGE_NOW=`cat $BAT/charge_now`
        CHARGE_FULL=`cat $BAT/charge_full`
        PERCENT=`echo "($CHARGE_NOW * 100)/$CHARGE_FULL" | bc`
        STATUS=`cat $BAT/status`

        if [ $STATUS == "Charging" ]; then
            STATUS="+"
        elif [ $STATUS == "Discharging" ]; then
            STATUS="-"
        else
            STATUS=""
        fi

        echo "B$STATUS$PERCENT"
        sleep 1
    done
}

# Now panel_bar, which was mostly taken from the example panel_bar, with a
# handful of improvements.

# - functionified, from panel_bar file of example
# - the output changes based on the number of monitors, to place a single
# monitors's information on that same monitor, instead of all in one corner.
# - added B header for battery
# - all the desktop indicators are enumerated

num_mon=$(bspc query -M | wc -l)

wm_info_array=("" "" "" "" "")

function panel_bar {
    while read line < $PANEL_FIFO; do
        case $line in
            S*)
                # clock output
                date="${line#?}"
                ;;
            B*)
                # battery output
                percent="${line#?}"
                ;;
            T*)
                # xtitle output
                title="%{F$COLOR_TITLE_FG}%{B$COLOR_TITLE_BG} ${line#?} %{B-}%{F-}"
                ;;
            W*)
                # bspwm internal state
                wm_infos=""
                cur_mon=-1
                desktop_num=1

                IFS=':'
                set -- ${line#?}
                while [ $# -gt 0 ] ; do
                    item=$1
                    name=${item#?}
                    case $item in
                        M*)
                            # active monitor
                            cur_mon=$((cur_mon + 1))
                            wm_infos=""
                            if [ $num_mon -gt 1 ] ; then
                                wm_infos="$wm_infos %{F$COLOR_ACTIVE_MONITOR_FG}%{B$COLOR_ACTIVE_MONITOR_BG} ${name} %{B-}%{F-}  "
                            fi
                            ;;
                        m*)
                            # inactive monitor
                            cur_mon=$((cur_mon + 1))
                            wm_infos=""
                            if [ $num_mon -gt 1 ] ; then
                                wm_infos="$wm_infos %{F$COLOR_INACTIVE_MONITOR_FG}%{B$COLOR_INACTIVE_MONITOR_BG} ${name} %{B-}%{F-}  "
                            fi
                            ;;
                        O*)
                            # focused occupied desktop
                            wm_infos="$wm_infos%{F$COLOR_FOCUSED_OCCUPIED_FG}%{B$COLOR_FOCUSED_OCCUPIED_BG}%{U$COLOR_FOREGROUND}%{+u} ${desktop_num}. ${name} %{-u}%{B-}%{F-}"
                            desktop_num=$((desktop_num + 1))
                            ;;
                        F*)
                            # focused free desktop
                            wm_infos="$wm_infos%{F$COLOR_FOCUSED_FREE_FG}%{B$COLOR_FOCUSED_FREE_BG}%{U$COLOR_FOREGROUND}%{+u} ${desktop_num}. ${name} %{-u}%{B-}%{F-}"
                            desktop_num=$((desktop_num + 1))
                            ;;
                        U*)
                            # focused urgent desktop
                            wm_infos="$wm_infos%{F$COLOR_FOCUSED_URGENT_FG}%{B$COLOR_FOCUSED_URGENT_BG}%{U$COLOR_FOREGROUND}%{+u} ${desktop_num}. ${name} %{-u}%{B-}%{F-}"
                            desktop_num=$((desktop_num + 1))
                            ;;
                        o*)
                            # occupied desktop
                            wm_infos="$wm_infos%{F$COLOR_OCCUPIED_FG}%{B$COLOR_OCCUPIED_BG} ${desktop_num}. ${name} %{B-}%{F-}"
                            desktop_num=$((desktop_num + 1))
                            ;;
                        f*)
                            # free desktop
                            wm_infos="$wm_infos%{F$COLOR_FREE_FG}%{B$COLOR_FREE_BG} ${desktop_num}. ${name} %{B-}%{F-}"
                            desktop_num=$((desktop_num + 1))
                            ;;
                        u*)
                            # urgent desktop
                            wm_infos="$wm_infos%{F$COLOR_URGENT_FG}%{B$COLOR_URGENT_BG} ${desktop_num}. ${name} %{B-}%{F-}"
                            desktop_num=$((desktop_num + 1))
                            ;;
                        L*)
                            # layout
                            wm_infos="$wm_infos %{F$COLOR_LAYOUT_FG}%{B$COLOR_LAYOUT_BG} ${name} %{B-}%{F-}"
                            ;;
                    esac
                    shift
                    wm_info_array[cur_mon]="$wm_infos"
                done
                ;;
        esac

        if [ $num_mon -eq 1 ]; then
            fmt="%{l}${wm_info_array[0]}%{c}${title}%{r}${percent} ${date}"
        elif [ $num_mon -eq 2 ]; then
            fmt="%{l}${wm_info_array[0]}%{c}${title}%{S+}%{l}${wm_info_array[1]}%{r}${percent} ${date}"
        else
            # Same as 2 -- needs someone to test
            fmt="%{l}${wm_info_array[0]}%{c}${title}%{S+}%{l}${wm_info_array[1]}%{r}${percent} ${date}"
        fi

        printf "%s\n" "$fmt"
    done
}

# Actually invoking the panel and piping to bar

panel_bar | bar -g x$PANEL_HEIGHT -f "$PANEL_FONT_FAMILY" -F "$COLOR_FOREGROUND" -B "$COLOR_BACKGROUND" &

# Hostname tweaks, including forcing stalonetray into a reasonable place, and
# starting the battery monitor on my laptop

HOSTNAME=`hostname`

# Echelon dual monitor, tray should be upper right corner of left monitor

if [ $HOSTNAME == "echelon" ]; then
    TRAY_GEOM="1x1-1920"

# Toadite single monitor, avoid date and battery

elif [ $HOSTNAME == "toadite" ]; then
    bat_percent > "$PANEL_FIFO" &
    TRAY_GEOM="1x1-100"

# Good for single monitor, just about enough room to avoid the date output

else
    TRAY_GEOM="1x1-75"
fi

stalonetray --geometry $TRAY_GEOM -i $PANEL_HEIGHT -bg "#34322e" --grow-gravity NE --kludges force_icons_size &

wait
