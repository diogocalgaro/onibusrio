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

O script fica rodando indefinidamente, até ser interrompido com Ctrl-C. Ele baixa os dados, monta uma página HTML e abre o navegador. A partir daí ele continuar baixando os dados e reconstruindo a página HTML (sem precisar reabrir a página no navegador). A página tem uma tag meta-refresh que indica para o navegador que deve recarregá-la a cada X segundos.

O tempo padrão dessa operação é de 2 minutos, mas pode ser alterado nos parâmetros de configuração que ficam no começo do código do script.
