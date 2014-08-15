OnibusRio
=========

Script em Bash que utiliza os dados de GPS da frota de ônibus municipais do Rio de Janeiro para fazer o acompanhamento de uma determinada linha de ônibus, usando a API pública do Google Maps.

=====

Pré-requisitos:

Bash 4.x
Sqlite 3.x
Navegador Web

=====

Execute o script num terminal com:

$ ./onibus.sh [numero da linha]

Se espeficicar o número, ele carrega diretamente essa linha. Se não especificar, ele vai carregar todas as linhas do webservice da prefeitura para mostrar a relação das linhas pra escolher.

