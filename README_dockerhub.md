# Tags supportati e link ai rispettivi `Dockerfile`
* [`3.0.1`, `latest` (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/master/standalone_bin/Dockerfile)

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

![Logo GovWay](https://govway.org/assets/images/gway_logo.svg "L'API gateway per la pubblica amministrazione italiana")

# Come utilizzare l'immagine

## Avviare l'immagine

Eseguire il _run_ dell'immagine:

```console 
docker run linkitaly/govway
```

I servizi e le interfacce web di GovWay sono accessibili sia su protocollo HTTP, che su protocollo HTTPS sulle porte 8080 e 8443 rispettivamente:


```console 
docker run -p 8080:8080 \
-p 8443:8443 \
linkitaly/govway
```

Per maggiori informazioni sull'accesso e l'utilizzo  fare riferimento alla documentazione del progetto [GovWay-Docker][3] e alla manualistica presente su [GovWay.org](https://govway.org/download).


I files interni utilizzati da GovWay: le properties di configurazione, i certificati SSL di esempio, il database HSQL ed i file di log, sono posizionati tutti sotto la directory standard /var/govway; si possono quindi rendere tutti persistenti montando un volume su questa directory


```console 
mkdir ~/govway_home

docker run -p 8080:8080 \
 -p 8443:8443 \
 -v ~/govway_home:/var/govway \
linkitaly/govway
```

## Personalizzare l'avvio
E' possibile personalizzare l'immagine all'avvio impostando alcune variabili d'ambiente. Al momento sono supportate le seguenti:
* __**FQDN**__: utilizzato per personalizzare il campo *CN* del subject dei certificati generati; se non specificato viene usato il valore di default *test.govway.org*
* __**USERID**__: utilizzato per impostare l'id di sistema dell'utente tomcat
* __**GROUPID**__: utilizzato per impostare l'id di sistema dell'utente tomcat


```console 
mkdir ~/govway_home

docker run -p 8080:8080 \
 -p 8443:8443 \
 -v ~/govway_home:/var/govway \
 -e "FQDN=`hostname -f`" -e "USERID=`$(id -u $USER)`" -e "GROUPID=`$(id -g $USER)`"
 govway_standalone:3.0.1
linkitaly/govway
```
[3]: https://github.com/link-it/govway-docker "Progetto Govway-Docker"
