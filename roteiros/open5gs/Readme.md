# Roteiro de testes de failover com o núcleo Open5GS

## Preparação

Para a execução deste roteiro assume-se que todos componentes do núcleo Open5GS estão funcionais; o imsi do simcard que será usado no UE está cadastrado no banco de dados do núcleo; a gnb srsRAN está configurada e com o sinal irradiando.

## 1. Conexões do UE

Além da conexão com a rede móvel, o equipamento do usuário também deverá possuir uma conexão cabeada para comunicação direta com o servidor que hospeda o núcleo 5G

## 2. Execução do teste

A partir do UE o comando abaixo deve ser executado:

`ping_failover.sh & sleep 5 && docker -H ssh://cerise@ws1:2376 kill upf1`
