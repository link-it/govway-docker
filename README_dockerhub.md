<img height="70px" alt="Logo GovWay" src="https://govway.org/assets/images/gway_logo.svg">

# Docker Image


## Tags supportati e link ai rispettivi Dockerfile

* [`3.3.5.p1`, `3.3.5.p1_standalone`, `latest` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5.p1_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5.p1_run_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5.p1_manager_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5.p1_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5.p1_run_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5.p1_manager_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5.p1/govway/Dockerfile.govway)
* [`3.3.5`, `3.3.5_standalone` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5/govway/Dockerfile.govway)
* [`3.3.5_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5/govway/Dockerfile.govway)
* [`3.3.5_run_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5/govway/Dockerfile.govway)
* [`3.3.5_manager_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.5/govway/Dockerfile.govway)
* [`3.3.4.p2` (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.4.p2/standalone_bin/Dockerfile)
* [`3.3.4.p2_postgres` (compose_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.4.p2/compose_bin/Dockerfile)

## Riferimenti al progetto
* [Informazioni sul progetto GovWay](https://govway.org/)
* [Sorgenti GovWay su GitHub](https://github.com/link-it/govway)
* [Progetto Govway-Docker su GitHub](https://github.com/link-it/govway-docker)

## Cosa è GovWay
Dall’esperienza della Porta di Dominio italiana, l’API Gateway conforme alle normative della Pubblica Amministrazione:

* Conformità agli standard di mercato: gestione protocolli standard di mercato, come SOAP 1.1 e 1.2, API restful serializzate in Json o XML o semplici dati binari su Http.
* Conformità alle specifiche italiane per l'interoperabilità: supporto delle nuove linee guida per l'interoperabilità di AGID (ModI PA). Viene inoltre assicurata la retrocompatibilità con il protocollo SPCoop, ancora ampiamente adottato per i servizi della PA.
* Conformità alle specifiche dell'interoperabilità europea: supporto supporto del protocollo AS4, tramite integrazione con il Building Block eDelivery del progetto europeo CEF (Connecting European Facilities).
* Conformità alle specifiche per la fatturazione elettronica sul canale SdiCoop.



## Nomenclatura delle immagini fornite

- **standalone**: fornisce un ambiente di prova di GovWay funzionante dove i dati di configurazione e tracciamento vengono mantenuti su un database HSQL interno al container;

- **postgres** o **oracle**: fornisce un'installazione che consente di avere i dati di configurazione e tracciamento su un database postgresql o oracle, gestito esternamente o su ambienti orchestrati (Es. Kubernetes, OpenShift).

Esistono ulteriori immagini che consentono di mantenere i dati su un database postgresql o oracle esterno, ma suddividono i componenti applicativi tra componenti di runtime e componenti dedicati alla gestione e il monitoraggio. Una suddivisione dei componenti consente di attuare una scalabilità dei nodi run proporzionata alla mole di richieste che devono essere gestite dall'api gateway:

- **run_postgres** o **run_oracle**: contiene solamente il componente runtime di api gateway;

- **manager_postgres** o **manager_oracle**: contiene solamente le console e i servizi API di configurazione e monitoraggio.


## Avviare l'immagine standalone

Eseguire il _run_ dell'immagine:

```console 
$ docker run \
  -e GOVWAY_POP_DB_SKIP=false \
linkitaly/govway
```

I servizi e le interfacce web di GovWay sono accessibili sia su protocollo HTTP, che su protocollo AJP sulle porte 8080 e 8009 rispettivamente:

```console 
$ docker run \
 -e GOVWAY_POP_DB_SKIP=false \
 -p 8080:8080 -p 8009:8009 \
linkitaly/govway
```

Per maggiori informazioni sulle console fare riferimento alla documentazione del progetto [GovWay](https://govway.org/documentazione/).

I files, interni all'immagine, utilizzati da GovWay sono: 
- le properties di configurazione, posizionati nella directory **/etc/govway**;
- i file di log, posizionati nella directory **/var/log/govway**;
- il database HSQL situato in **/opt/hsqldb-2.6.1/hsqldb/database**.

Si possono rendere persistenti i file sopra indicati montando un volume per ogni directory indicata:

```console 
$ mkdir ~/govway_home
$ mkdir ~/govway_log
$ mkdir ~/govway_db
$ docker run \
 -e GOVWAY_POP_DB_SKIP=false \
 -p 8080:8080 -p 8009:8009 \
 -v ~/govway_home:/etc/govway \
 -v ~/govway_log:/var/log/govway \
 -v ~/govway_db:/opt/hsqldb-2.6.1/hsqldb/database
linkitaly/govway
```
Nota: abilitando la variabile 'GOVWAY_POP_DB_SKIP' non verra effettuata l'inizializzazione della base dati.


## Avviare una delle immagini orchestrate

Utilizzando docker-compose come esempio di ambiente orchestrato, è possibile utilizzare un docker-compose.yml simile al seguente per database postgresql:

```yaml
version: '2'
 services:
  govway:
    container_name: govway
    image: linkitaly/govway:3.3.5.p1_postgres
    ports:
        - 8080:8080
        - 8009:8009
    volumes:
        - ~/govway_home:/etc/govway
        - ~/govway_log:/var/log/govway
    environment:
        - GOVWAY_DB_SERVER=postgres_hostname:5432
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_POP_DB_SKIP=true
```

Un esempio di docker-compose per oracle è invece il seguente:

```yaml
version: '2'
 services:
  govway:
    container_name: govway
    image: linkitaly/govway:3.3.5.p1_oracle
    ports:
        - 8080:8080
        - 8009:8009
    volumes:
        - ~/govway_home:/etc/govway
        - ~/govway_log:/var/log/govway
        - ~/oracle11g/ojdbc7.jar:/tmp/ojdbc7.jar
    environment:
        - GOVWAY_ORACLE_JDBC_PATH=/tmp/ojdbc7.jar
        - GOVWAY_DB_SERVER=oracle_hostname:1521
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_ORACLE_JDBC_URL_TYPE=ServiceName
        - GOVWAY_POP_DB_SKIP=true
```


I containers vengono avviati con i seguenti comandi:

```console
$ mkdir -p govway_{conf,log}
$ chmod 777 govway_{conf,log}
$ docker-compose up
```

Per maggiori informazioni sulle variabili che possono essere utilizzate per personalizzare l'immagine fare riferimento alla documentazione del progetto [Govway-Docker](https://github.com/link-it/govway-docker).
