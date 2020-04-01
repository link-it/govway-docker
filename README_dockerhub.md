# Tags supportati e link ai rispettivi `Dockerfile`
* [`3.3.0`, `latest`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw330/standalone_bin/Dockerfile)
* [`3.3.0_postgres`, (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw330/compose_bin/Dockerfile)
* [`3.2.2`, `latest`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.2.2/standalone_bin/Dockerfile)
* [`3.2.2_postgres`, (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.2.2/compose_bin/Dockerfile)
* [`3.2.1`, `latest`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.2.1/standalone_bin/Dockerfile)
* [`3.2.1_postgres`, (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.2.1/compose_bin/Dockerfile)
* [`3.2.0`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.2.0/standalone_bin/Dockerfile)
* [`3.2.0_postgres`, (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.2.0/compose_bin/Dockerfile)


# Riferimenti al progetto
* [Informazioni sul progetto GovWay](https://govway.org/)
* [Sorgenti GovWay su GitHub](https://github.com/link-it/govway)
* [Progetto Govway-Docker su GitHub][3]

# Cosa è GovWay
Dall’esperienza della Porta di Dominio italiana, l’API Gateway conforme alle normative della Pubblica Amministrazione:

* Conformità agli standard di mercato: gestione protocolli standard di mercato, come SOAP 1.1 e 1.2, API restful serializzate in Json o XML o semplici dati binari su Http.
* Conformità alle specifiche italiane per l'interoperabilità: supporto delle nuove linee guida per l'interoperabilità di AGID (ModI PA). Viene inoltre assicurata la retrocompatibilità con il protocollo SPCoop, ancora ampiamente adottato per i servizi della PA.
* Conformità alle specifiche dell'interoperabilità europea: supporto supporto del protocollo AS4, tramite integrazione con il Building Block eDelivery del progetto europeo CEF (Connecting European Facilities).
* Conformità alle specifiche per la fatturazione elettronica sul canale SdiCoop.

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
* __**GOVWAY_INTERFACE**__: utilizzato per scegliere che tipo di interfacce (rest o web), utilizzare per il monitoraggio e la configurazione di GovWay.

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
