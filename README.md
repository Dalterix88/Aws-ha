# Aws-ha
Ha wordpress cluster on AWS

L'infrastruttura è composta dai seguenti elementi :

1 VPC con 2 subnet pubbliche e 2 private
4 istanze webserver con wordpress (eu-central-1a / eu-central-1b) 2 per ogni zona
1 istanza RDS per ogni zona (eu-central-1a / eu-central-1b)
1 load balancer

Isturzioni per il Deploy : 

1) clonare questa repo
2) installare amazon-cli + terraform
3) creare una chiave d'accesso nella zona eu-central-1
4) creare una coppia di chiavi nella zona eu-central-1
5) configurare sulla macchina le chiavi di accesso tramite il comando "aws configure"
6) inizializzare il deploy tramite il comando "terraform init" successivamente "terraform plan" ed infine "terraform apply"
7) collegarsi all'output "ec2ip" all'indirizzo http://"ec2ip"/wordpress/ ed inserire i parametri db per l'installazione di wordpress ( li trovate all'interno del main.tf) mentre l'hostaname del db lo trovate nell'output finale del deploy


Note : una volta installata la prima istanza , per quanto riguarda le altre 3 istanze sara' sufficente collegarsi tramite l'ip pubblico e andare all'indirizzo http://ipistanza/wordpress/ , inserire di nuovo i parametri del db e l'istanza riconoscera' che wordpress è gia installato e configurato.
