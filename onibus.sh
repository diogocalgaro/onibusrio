#!/bin/bash
#
# Parametros
#
# $1 = numero de linha de onibus => carrega diretamente as informacoes daquela linha,
#                                   ao inves de carregar todas as linhas numa lista de selecao
#
# $2 = "-manter" => se o segundo parametro tiver esse valor, não vai apagar a base de dados ao iniciar
#

#config
intervalo_html=120 #em segundos
intervalo_script=100 #deve ser menor que o anterior
naveg_opcoes="google-chrome firefox konqueror opera" #preferencia para uso dos navegadores (separado por espaço)

#variaveis
versao="0.1"
base="$(pwd)"
arq="$(mktemp)"
arq2="$(mktemp)"
html0="$(mktemp)"
html="${base}/onibus.html"
nomes="${base}/linhas_onibus.txt"
sql="$(mktemp)"
url="http://dadosabertos.rio.rj.gov.br/apiTransporte/apresentacao/csv/onibus.cfm"
db="${base}/dados.db"

#funcoes
function sair {
	echo -n  "Saindo... "
	rm ${arq} 2>/dev/null
	rm ${arq2} 2>/dev/null
	rm ${html0} 2>/dev/null
	rm ${sql} 2>/dev/null
	echo "[OK]"
	exit 0
}

trap sair SIGINT SIGTERM SIGQUIT

#inicio
echo "Script de acompanhamento de ônibus (versão ${versao})"
echo

#verificando se a linha foi passada como 1o. parametro
if [ -n "$1" ]
then
	cod="$1"
	txt="$(grep -m1 "^${cod}" $nomes)"
	txt="${txt#*=}"
	tput setf 3
	echo "Linha: ${txt}"
	tput sgr0
	echo
else
       	echo -n "Obtendo as linhas disponíveis... "
        curl --compressed -s -o "$arq" "$url" 2>/dev/null || \
       	        aria2c -q -o "$arq" "$url" 2>/dev/null || \
               	        wget -q -O "$arq" --no-use-server-timestamps "$url" 2>/dev/null || \
                       	        (echo -e "\nNenhum programa de download disponível..." ; exit 1)
	echo "[OK]"

	#selecionando a linha de onibus
	echo "Obtendo as linhas de onibus..."
	grep -v '^data' "$arq" | awk -F',' '{ print $3 }' | grep -v '^$'| sort | uniq -c > "$arq2"
	max=$(wc -l $arq2 | cut -d' ' -f1)
	j=0
	tmp1="$(mktemp)"

	
	while read i
	do
		#obtendo os dados
		lin=${i#* }
		qtd=${i% *}
		txt="$(grep -m1 "^${lin}" $nomes)"
		txt="${txt#*=}"

		if [ -z "${txt}" ]
		then
			txt="(Nome da linha indisponível)"
		fi

		#salvando em arquivo temporario
		echo "${lin} '${txt}   [${qtd}]'" >> "$tmp1"

		(( j++ ))
		perc=$(echo "scale=2;${j}/${max}*100" | bc)
		perc=$(echo "${perc}/1" | bc)
		echo $perc
	done < "$arq2" | whiptail --gauge "Carregando os dados das linhas de ônibus disponíveis" 7 70 0

	opcoes="$(cat $tmp1 | tr '\n' ' ')"
	eval "cod=\$(whiptail --menu 'Selecione a linha' 40 110 32 ${opcoes} 3>&2 2>&1 1>&3)"
	rm ${tmp1} 2>/dev/null
	test -z "${cod}" && exit 0
fi

#verificando banco de dados
if [ -f "${db}" ]
then
	test "${2}" != "-manter" && sqlite3 ${db} "delete from onibus;"
else
	sqlite3 ${db} "create table onibus (carro text, x text, y text, quando timestamp);"
fi

#definindo o navegador
naveg="$(which ${naveg_opcoes} xdg-open 2>/dev/null | head -n1)"

#laco principal
prim='s'
while true
do
	#baixando a pagina com os dados de gps
	if [ -n "${url}" ]
	then
        	echo -n "Obtendo os dados de GPS... "
	        curl --compressed -s -o "$arq" "$url" 2>/dev/null || \
        	        aria2c -q -o "$arq" "$url" 2>/dev/null || \
                	        wget -q -O "$arq" --no-use-server-timestamps "$url" 2>/dev/null || \
                        	        (echo -e "\nNenhum programa de download disponível..." ; exit 1)
		echo "[OK]"
	else
        	echo "Usando cache local"
	        cat "dados.exemplo" > ${arq} || exit 1
	fi

	#limpando arquivo complementar
	echo > ${html0}

	#pegando as posicoes da linha escolhida
	echo "begin transaction;" > ${sql}
	while read i
	do
		IFS=',' read qnd carro linha x y vel <<< "${i}"
		x=${x//\"}
		y=${y//\"}
		IFS='-' read m d Y <<< "${qnd% *}"
		qnd="${d}/${m}/${Y} ${qnd#* }"
		echo "${carro} = ${x}, ${y} [${qnd}]"
		echo "insert into onibus (carro, x, y, quando) values ('${carro}', '${x}', '${y}', '${qnd}');" >> ${sql}
		cat >> ${html0} <<EOF
			var marker = new google.maps.Marker({
				position: new google.maps.LatLng(${x},${y}),
				map: map,
				title: '${carro}'
			});
EOF
	done < <(grep ','${cod}',"' "${arq}")
	echo "commit;" >> ${sql}
	sqlite3 ${db} ".read ${sql}"

	#pegando o centro do mapa
	res=$(sqlite3 -csv -separator "," ${db} "select x,y from onibus order by carro, quando desc limit 1")
	IFS=',' read cx cy <<< "${res}"

	#gerando o HTML com o mapa
	echo -n "Gerando o mapa... "
	cat > ${html} <<EOF
<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="refresh" content="${intervalo_html}">
	<meta name="viewport" content="initial-scale=1.0, user-scalable=no">
	<meta charset="utf-8">
	<title>${cod} - GPS</title>
	<style>
		html, body, #map-canvas {
			height: 100%;
			margin: 0px;
			padding: 0px
		}
	</style>
	<script src="https://maps.googleapis.com/maps/api/js?v=3.exp"></script>
	<script>
		function initialize() {
			var myLatlng = new google.maps.LatLng(${cx},${cy});
			var mapOptions = {
				zoom: 15,
				center: myLatlng
			}
			var map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
EOF
	#inserindo os onibus no mapa
	cat ${html0} >> ${html}

	#pegando a trajetoria
	old_carro=""
	traj=0
	while read t
	do
		IFS=',' read tcarro tx ty <<< "${t}"
		if [ "${old_carro}" != "${tcarro}" ]
		then
			if [ -n "${old_carro}" ]
			then
				cat >> ${html} <<EOF
			];
			var traj_item_${traj} = new google.maps.Polyline({
				path: traj_coord_${traj},
				geodesic: true,
				strokeColor: '#FF0000',
				strokeOpacity: 1.0,
				strokeWeight: 2
			});
			traj_item_${traj}.setMap(map);
EOF
			fi

			(( traj++ ))

			cat >> ${html} <<EOF
			var traj_coord_${traj} = [
EOF
			old_carro="${tcarro}"
		fi

		cat >> ${html} <<EOF
				new google.maps.LatLng(${tx},${ty}),
EOF
	done < <(sqlite3 -csv -separator "," ${db} "select distinct carro, x, y from onibus order by carro, quando desc;")

	if [ -n "${old_carro}" ]
	then
		cat >> ${html} <<EOF
			];
			var traj_item_${traj} = new google.maps.Polyline({
				path: traj_coord_${traj},
				geodesic: true,
				strokeColor: '#FF0000',
				strokeOpacity: 1.0,
				strokeWeight: 2
			});
			traj_item_${traj}.setMap(map);
EOF
	fi

	#terminando o html
	cat >> ${html} <<EOF
		}
		google.maps.event.addDomListener(window, 'load', initialize);
	</script>
	</head>
	<body>
		<div id="map-canvas"></div>
	</body>
</html>
EOF
	echo "[OK]"

	#abrindo o navegador
	if [ "${prim:-s}" == "s" ]
	then
		echo -n "Abrindo navegador... "
		$naveg "file://${html}?${cod}" >/dev/null 2>&1 &
		echo "[OK]"
		prim="n"
	fi

	#intervalo
	sleep ${intervalo_script} 
done
