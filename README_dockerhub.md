# Tags supportati e link ai rispettivi `Dockerfile`
* [`3.2.0`, `latest`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/master/standalone_bin/Dockerfile)
* [`3.2.0_postgres`, (standalone_compose/Dockerfile)](https://github.com/link-it/govway-docker/blob/master/compose_bin/Dockerfile)
* [`3.1.1`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/891d372a25cd55991cf34cde412223f41ee5638c/standalone_bin/Dockerfile)
* [`3.1.1_postgres`, (standalone_compose/Dockerfile)](https://github.com/link-it/govway-docker/blob/891d372a25cd55991cf34cde412223f41ee5638c/compose_bin/Dockerfile)
* [`3.1.0`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/8789a3e0b65bea1f139b8de891bd6819f1daa2d3/standalone_bin/Dockerfile)
* [`3.1.0_postgres`, (standalone_compose/Dockerfile)](https://github.com/link-it/govway-docker/blob/0521e6f4467df94837fa3fe33f024faa93be2a5a/compose_bin/Dockerfile)


# Riferimenti al progetto
* [Informazioni sul progetto GovWay](https://govway.org/)
* [Sorgenti GovWay su GitHub](https://github.com/link-it/govway)
* [Progetto Govway-Docker su GitHub][3]

# Cosa è GovWay
Dall’esperienza della Porta di Dominio italiana, l’API Gateway conforme alle normative della Pubblica Amministrazione:
* Conforme alle nuove linee guida AGID per l’interoperabilità ModI 2018 (profilo API Gateway)
* Conforme alle specifiche per l’interoperabilità europea (profilo eDelivery)
* Conforme alle specifiche per la fatturazione elettronica sul canale SdiCoop (profilo Fatturazione Elettronica)
* Retrocompatibile con il paradigma di cooperazione applicativa (profilo SPCoop)
* Connettori preconfigurati (GovLet) per l’accesso ai principali servizi pubblici italiani

<img height="70px" alt="Logo GovWay" src="https://govway.org/assets/images/gway_logo.svg">

# Come utilizzare l'immagine

## Avviare l'immagine

Eseguire il _run_ dell'immagine:

```console 
$ docker run linkitaly/govway
```

I servizi e le interfacce web di GovWay sono accessibili sia su protocollo HTTP, che su protocollo HTTPS sulle porte 8080 e 8443 rispettivamente:


```console 
$ docker run \
 -p 8080:8080 -p 8443:8443 \
linkitaly/govway
```

Per maggiori informazioni sull'accesso e l'utilizzo  fare riferimento alla documentazione del progetto [GovWay-Docker][3] e alla manualistica presente su [GovWay.org](https://govway.org/download).


I files interni utilizzati da GovWay: le properties di configurazione, i certificati SSL di esempio, il database HSQL ed i file di log, sono posizionati tutti sotto la directory standard /var/govway; si possono quindi rendere tutti persistenti montando un volume su questa directory:


```console 
$ mkdir ~/govway_home
$ docker run \
 -p 8080:8080 -p 8443:8443 \
 -v ~/govway_home:/var/govway \
linkitaly/govway
```

## Personalizzare l'avvio
E' possibile personalizzare l'immagine all'avvio impostando alcune variabili d'ambiente. Al momento sono supportate le seguenti:
* __**FQDN**__: utilizzato per personalizzare il campo *CN* del subject dei certificati generati; se non specificato viene usato il valore di default *test.govway.org*
* __**USERID**__: utilizzato per impostare l'id di sistema dell'utente tomcat
* __**GROUPID**__: utilizzato per impostare l'id di sistema dell'utente tomcat
* __**SSH_PUBLIC_KEY**__: utilizzato per registrare una chiave pubblica, tra gli host autorizzati a collegarsi al server SSH interno

```console 
$ mkdir ~/govway_home
$ docker run \
 -p 8080:8080 -p 8443:8443 \
 -v ~/govway_home:/var/govway \
 -e "FQDN=$(hostname -f)" \ 
 -e "USERID=$(id -u $USER)" -e "GROUPID=$(id -g $USER)" \
 -e "SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)" \
linkitaly/govway
```
[3]: https://github.com/link-it/govway-docker "Progetto Govway-Docker"
