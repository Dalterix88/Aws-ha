# Aws-ha
Ha wordpress cluster on AWS

L'infrastruttura è composta dai seguenti elementi :

2 VPC con 2 subnet pubbliche e 2 private

4istanze webserver con wordpress (eu-central-1a / eu-central-1b) 2 per ogni zona

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

Nota 2 : Ho strutturato il file main.tf in varie sezioni in modo da specificare a quale funzione è adibita ogni sezione.
___________________________________________________________________________________________________________________________________________

L'infrastruttura del main2.tf è composta dai seguenti elementi :

1x VPN con x2 subnets pubbliche e x2 subnets private

4x EC2 istanze EC2 (2x eu-central-1a / 2x eu-central-1b)

1x RDS cluster (1x eu-central-1a / 1x eu-central-1b)

1x load balancer (eu-central-1a / eu-central-1b)

1x Internet gateway

Istruzioni per il deploy dell'infra : 

1) clonare questa repo
2) installare amazon-cli + terraform
3) creare una chiave d'accesso nella zona eu-central-1
4) creare una coppia di chiavi nella zona eu-central-1
5) configurare sulla macchina le chiavi di accesso tramite il comando "aws configure"
6) inizializzare il deploy tramite il comando "terraform init" successivamente "terraform plan" ed infine "terraform apply"
7) collegarsi all'indirizzo del load balancer , l'istanza di wordpress sara' gia configurata e vi si potra' accedere al wp-admin tramite l'url http://lbip/wp-admin usando le credenziali che sono contenute nel file "install_wordpress.sh"




