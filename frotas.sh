#!/bin/bash

while IFS='=' read a b
do
	a="L${a}"
	eval "${a}='"${b}"'"
done < linhas_onibus.txt

Lx="[Sem linha definida]"
tmp=$(mktemp)

while IFS=',' read a b c d e f
do
	echo ${c:-'x'} $b
done < onibus.cfm.csv | sort -u | awk '{ print $1 }' | uniq -c | sort -n > $tmp

while read i
do
	linha="L"$(echo $i | cut -d' ' -f2)
	echo "$i -  ${!linha}"
done < $tmp
