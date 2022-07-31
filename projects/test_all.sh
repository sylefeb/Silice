#!/bin/bash
IFS=$'\n'
dirs=$(find -maxdepth 2 -name 'configs' -printf '%h\n' | sort -u)
for i in $dirs; do
    if [ "$i" = "./doomchip" ]; then
        echo "Skipping $i"
    else
        configs=`cat $i/configs`
        for config in $configs; do
            printf "%-30s" $i
            config_trimed=`echo $config`
            printf "%-30s" $config_trimed
            mkcmd="make -C $i -f $config_trimed ARGS=\"--no_build\"";
            cmd_out=`eval $mkcmd 2>&1`
            has_err=$(echo $cmd_out | grep -i "error");
            if [ -z "$has_err" ];
            then
                printf " [COMPILED]\n"
            else
                printf " [ FAILED ]\n       %s\n" "$mkcmd"
            fi
        done
    fi
done
