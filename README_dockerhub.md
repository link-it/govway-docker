# Tags supportati e link ai rispettivi `Dockerfile`

* [`3.3.5`, `3.3.5_standalone`, `latest`, (govway/Dockerfile.govway)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`3.3.5_postgres`, `3.3.5_postgres_all`, (govway/Dockerfile.govway)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`3.3.5_postgres_run`, (govway/Dockerfile.govway)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`3.3.5_postgres_manager`, (govway/Dockerfile.govway)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`3.3.4.p2`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.4.p2/standalone_bin/Dockerfile)
* [`3.3.4.p2_postgres`, (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.4.p2/compose_bin/Dockerfile)
* [`3.3.4.p1`, (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.4.p1/standalone_bin/Dockerfile)
* [`3.3.4.p1_postgres`, (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.4.p1/compose_bin/Dockerfile)

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

# Nomenclatura delle immagini fornite
**standalone**: Installazione GovWay indipendente. Tutti i dati vengono scritti su un datbase HSQL interno al container

**postgres_all**: Installazione GovWay da utilizzare in ambienti dove il database è gestito esternamente o su ambienti orchestrati (Es. Kubernetes, OpenShift)

**postgres_run**: Come postgres_all, ma l'immaginre contiene solo le componenti di api gateway

**postgres_manager**: Come postgres_all, ma l'immaginre contiene solo le interfacce web di configurazione e monitoraggio.

## Avviare l'immagine standalone

Eseguire il _run_ dell'immagine:

```console 
$ docker run linkitaly/govway
```

I servizi e le interfacce web di GovWay sono accessibili sia su protocollo HTTP, che su protocollo AJP sulle porte 8080 e 8009 rispettivamente:


```console 
$ docker run \
 -p 8080:8080 -p 8009:8009 \
linkitaly/govway
```

Per maggiori informazioni sull'accesso e l'utilizzo  fare riferimento alla documentazione del progetto [GovWay-Docker][3] e alla manualistica presente su [GovWay.org](https://govway.org/download).


I files interni utilizzati da GovWay: le properties di configurazione, il database HSQL ed i file di log, sono posizionati tutti sotto le directory standard **/etc/govway**, **/var/log/govway** ed **/opt/hsqldb-2.6.1/hsqldb/database** rispettivamente; si possono quindi rendere tutti persistenti montando un volume su questa directory:


```console 
$ mkdir ~/govway_home
$ docker run \
 -p 8080:8080 \
 -v ~/govway_home:/etc/govway \
 -v ~/govway_log:/var/log/govway
linkitaly/govway
```

## Avviare una delle immagini orchestrate
Utilizzando docker-compose come esempio di ambiente orchestrato, è possibile utilizzare un docker-compose.yml simile al seguente:

```yaml
version: '2'
 services:
  govway:
    container_name: govway-3.3.5_postgres
    image: linkitaly/govway:3.3.5_postgres
    ports:
        - 8080:8080
    volumes:
        - ./govway_conf:/etc/govway
        - ./govway_log:/var/log/govway
    depends_on:
        - database
    environment:
        - GOVWAY_DB_SERVER=pg_govway-3.3.5_postgres
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
  database:
    container_name: pg_govway-3.3.5_postgres
    image: postgres:13
    environment:
        - POSTGRES_DB=govwaydb
        - POSTGRES_USER=govway
        - POSTGRES_PASSWORD=govway
```

I containers vengono avviati con i seguenti comandi:

```console
$ mkdir -p govway_{conf,log}
$ chmod 777 govway_{conf,log}
$ docker-compose up
```

[3]: https://github.com/link-it/govway-docker "Progetto Govway-Docker"

