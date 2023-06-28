<img height="70px" alt="Logo GovWay" src="https://govway.org/assets/images/gway_logo.svg">

# Docker Image


## Tags supportati e link ai rispettivi Dockerfile

* [`3.3.13`, `3.3.13_standalone`, `latest` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_run_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_manager_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_batch_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_run_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_manager_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.13_batch_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.13/govway/Dockerfile.govway)
* [`3.3.12`, `3.3.12_standalone`, `latest` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_run_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_manager_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_batch_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_run_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_manager_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.12_batch_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.12/govway/Dockerfile.govway)
* [`3.3.11`, `3.3.11_standalone` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_run_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_manager_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_batch_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_run_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_manager_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)
* [`3.3.11_batch_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/gw_3.3.11/govway/Dockerfile.govway)

## Riferimenti al progetto
* [Informazioni sul progetto GovWay](https://govway.org/)
* [Sorgenti GovWay su GitHub](https://github.com/link-it/govway)
* [Progetto Govway-Docker su GitHub](https://github.com/link-it/govway-docker)

## Cosa è GovWay
Dall’esperienza della Porta di Dominio italiana, l’API Gateway conforme alle normative della Pubblica Amministrazione:

* Conformità agli standard di mercato: gestione protocolli standard di mercato, come SOAP 1.1 e 1.2, API restful serializzate in Json o XML o semplici dati binari su Http.
* Conformità alle specifiche italiane per l'interoperabilità: supporto delle nuove linee guida per l'interoperabilità di AGID (ModI) e gestione dei token rilasciati dalla PDND. Viene inoltre assicurata la retrocompatibilità con il protocollo SPCoop, ancora ampiamente adottato per i servizi della PA.
* Conformità alle specifiche dell'interoperabilità europea: supporto supporto del protocollo AS4, tramite integrazione con il Building Block eDelivery del progetto europeo CEF (Connecting European Facilities).
* Conformità alle specifiche per la fatturazione elettronica sul canale SdiCoop.



## Nomenclatura delle immagini fornite

- **standalone**: fornisce un ambiente di prova di GovWay funzionante dove i dati di configurazione e tracciamento vengono mantenuti su un database HSQL interno al container;

- **postgres** o **oracle**: fornisce un'installazione che consente di avere i dati di configurazione e tracciamento su un database postgresql o oracle, gestito esternamente o su ambienti orchestrati (Es. Kubernetes, OpenShift).

### Ambienti run e manager

Esistono ulteriori immagini che consentono di mantenere i dati su un database postgresql o oracle esterno, ma suddividono i componenti applicativi tra componenti di runtime e componenti dedicati alla gestione e il monitoraggio. Una suddivisione dei componenti consente di attuare una scalabilità dei nodi run proporzionata alla mole di richieste che devono essere gestite dall'api gateway:

- **run_postgres** o **run_oracle**: contiene solamente il componente runtime di api gateway;

- **manager_postgres** o **manager_oracle**: contiene solamente le console e i servizi API di configurazione e monitoraggio.

Le console disponibili nell'ambiente manager hanno la necessità di accedere ai seguenti servizi esposti dai nodi run:

- servizio 'check': consente di monitorare il servizio dei nodi run; è possibile invocare il contesto "/govway/check" di un qualsiasi nodo run (riferendo l'endpoint di esposizione del servizio dei nodi run) o un servizio fornito dal container;

- servizio 'proxy': consente di inviare un comando ad ogni nodo run attivo; deve essere indirizzato il servizio "/govway/proxy" di un qualsiasi nodo attivo.

L'indirizzamento utilizzato deve essere definito nel file '/etc/govway/govway.nodirun.properties' come segue:

```
# ===================================================================
# Indirizzamento servizi dei nodi 'run' 
# Servizio 'proxy'
GovWay.remoteAccess.url=http://<service-name>/govway/proxy
# Servizio 'check'
GovWay.remoteAccess.checkStatus.url=http://<service-name>/govway/check
# ===================================================================
```

## Avviare l'immagine standalone

Eseguire il _run_ dell'immagine:

> **_NOTA:_** la variabile 'GOVWAY_DEFAULT_ENTITY_NAME' consente di indicare il nome del soggetto operativo attivo sul dominio gestito attraverso GovWay.

```console 
$ docker run \
  -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
  -e GOVWAY_POP_DB_SKIP=false \
  -e TZ=Europe/Rome \
linkitaly/govway
```

I servizi e le interfacce web di GovWay sono accessibili sia su protocollo HTTP, che su protocollo AJP sulle porte 808* e 8009 rispettivamente (nella sezione 'Informazioni di Base' vengono fornite maggiori informazioni a riguardo):

```console 
$ docker run \
 -e GOVWAY_POP_DB_SKIP=false \
 -e TZ=Europe/Rome \
 -p 8080:8080 \
 -p 8081:8081 \
 -p 8082:8082 \
 -p 8009:8009 \
linkitaly/govway
```

Per maggiori informazioni sulle console fare riferimento alla documentazione del progetto [GovWay](https://govway.org/documentazione/).

I files, interni all'immagine, utilizzati da GovWay sono: 
- le properties di configurazione, posizionati nella directory **/etc/govway**;
- i file di log, posizionati nella directory **/var/log/govway**;
- il database HSQL situato in **/opt/hsqldb-2.7.1/hsqldb/database**.

Si possono rendere persistenti i file sopra indicati montando un volume per ogni directory indicata:

```console 
$ mkdir ~/govway_conf
$ mkdir ~/govway_log
$ mkdir ~/govway_db
$ docker run \
 -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
 -e GOVWAY_POP_DB_SKIP=false \
 -e TZ=Europe/Rome \
 -p 8080:8080 \
 -p 8081:8081 \
 -p 8082:8082 \
 -p 8009:8009 \
 -v ~/govway_conf:/etc/govway \
 -v ~/govway_log:/var/log/govway \
 -v ~/govway_db:/opt/hsqldb-2.7.1/hsqldb/database \
linkitaly/govway
```
> **_NOTA:_** abilitando la variabile 'GOVWAY_POP_DB_SKIP' non verra effettuata l'inizializzazione della base dati.


## Avviare una delle immagini orchestrate

Utilizzando docker-compose come esempio di ambiente orchestrato, è possibile utilizzare un docker-compose.yml simile al seguente per database postgresql:

> **_NOTA:_** la variabile 'GOVWAY_DEFAULT_ENTITY_NAME' consente di indicare il nome del soggetto operativo attivo sul dominio gestito attraverso GovWay.

```yaml
version: '2'
 services:
  govway:
    container_name: govway
    image: linkitaly/govway:3.3.13_postgres
    ports:
        - 8080:8080
        - 8081:8081
        - 8082:8082
        - 8009:8009
    volumes:
        - ~/govway_conf:/etc/govway
        - ~/govway_log:/var/log/govway
    environment:
        - TZ=Europe/Rome
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
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
    image: linkitaly/govway:3.3.13_oracle
    ports:
        - 8080:8080
        - 8081:8081
        - 8082:8082
        - 8009:8009
    volumes:
        - ~/govway_conf:/etc/govway
        - ~/govway_log:/var/log/govway
        - ~/oracle11g/ojdbc7.jar:/tmp/ojdbc7.jar
    environment:
        - TZ=Europe/Rome
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
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
$ mkdir -p ~/govway_{conf,log}
$ chmod 777 ~/govway_{conf,log}
$ docker-compose up
```

> **_NOTA:_** Per maggiori informazioni sulle variabili che possono essere utilizzate per personalizzare l'immagine fare riferimento alla documentazione del progetto [Govway-Docker](https://github.com/link-it/govway-docker).


## Informazioni di Base

### File interni all'immagine

I files, interni all'immagine, utilizzati da GovWay sono: 
- le properties di configurazione, posizionati nella directory **/etc/govway**;
- i file di log, posizionati nella directory **/var/log/govway**;
- in una immagine standalone il database HSQL è situato in **/opt/hsqldb-2.7.1/hsqldb/database**.

si possono rendere queste location persistenti, montando dei volumi su queste directory come mostrato negli esempi delle sezioni precedenti.

### Servizi attivi

Le immagini prodotte utilizzano come application server ospite WildFly 26.1.3.Final, in ascolto sia in protocollo _**AJP**_ sulla porta **8009** sia in _**HTTP**_ su 3 porte in modo da gestire il traffico su ogni porta, con un listener dedicato:
- **8080**: Listener dedicato al traffico in erogazione (max-thread-pool default: 100)
- **8081**: Listener dedicato al traffico in fruizione (max-thread-pool default: 100)
- **8082**: Listener dedicato al traffico di gestione (max-thread-pool default: 20)

Tutte queste porte sono esposte dal container e per accedere ai servizi dall'esterno si devono pubblicare al momento dell'avvio del immagine. 
Le interfacce web di monitoraggio configurazione sono quindi disponibili sulle URL:

```
 http://<indirizzo IP>:8082/govwayConsole/
 http://<indirizzo IP>:8082/govwayMonitor/
```
L'account di default per l'interfaccia **govwayConsole** è:
 * username: amministratore
 * password: 123456

L'account di default per l'interfaccia **govwayMonitor** è:
 * username: operatore
 * password: 123456

Il contesto di accesso ai servizi dell`API gateway per le erogazioni di API:
```
 http://<indirizzo IP>:8080/govway/
```

Il contesto di accesso ai servizi dell`API gateway per le fruizioni di API:
```
 http://<indirizzo IP>:8081/govway/
```

### Script SQL di inizializzazione della BaseDati

All'avvio del container, sia in modalità standalone che con immagini orchestrate, vengono eseguite delle verifiche sul database per assicurarne la raggiungibilità ed il corretto popolamento; in caso venga riconosciuto un database non inizializzato vengono utilizzatti gli scripts SQL interni per effettuare l'inizializzazione a meno che la variabile 'GOVWAY_POP_DB_SKIP' risulta abilitata.

Per esaminare gli script SQL di inizializzazione o utilizzarli manualmente è possibile recuperarli dall'immagine in una delle directory standard  **/opt/hsql**, **/opt/postgresql** o **/opt/oracle**. Ad esempio per l'immagine che utilizza un database 'postgresql' è possibile utilizzare il comando:

```shell
CONTAINER_ID=$(docker run -d -e GOVWAY_DEFAULT_ENTITY_NAME=Ente linkitaly/govway:3.3.13_postgres initsql)
docker cp ${CONTAINER_ID}:/opt/postgresql .
```



## Aggiornamento di Versione

Un upgrade richiede l'aggiornamento della base dati.

### Ambiente orchestrato

Se è stato utilizzato un docker-compose su ambiente orchestrato (postgresql o oracle) o un'immagine standalone con database montato su un volume esterno, per effettuare l'upgrade è necessario seguire i seguenti step:

- fermare ed eliminare il container contenente la precedente versione;

- aggiornare la base dati come indicato in [README.update](https://github.com/link-it/govway/blob/master/resources/sql_upgrade/README.update);

- riferire la nuova versione all'interno del docker-compose;

- riavvare il docker-compose. 

> **_NOTA:_** una volta applicate le patch di upgrade descritte in [README.update](https://github.com/link-it/govway/blob/master/resources/sql_upgrade/README.update) la base dati non risulta più compatibile con la precedente versione del software. Si consiglia di effettuare un backup prima di procedere con l'upgrade in modo da poter effettuare un eventuale downgrade di versione.


### Standalone

Nel caso di versione standalone in cui il database non sia stato montato su un volume esterno, è sufficiente avviare la nuova versione dell'immagine.

> **_NOTA:_** i dati contenuti all'interno del precedente container verranno persi.



## Ambienti batch

Le informazioni statistiche consultabili tramite la console di Monitoraggio consistono di informazioni aggregate su base periodica dei dati relativi alle transazioni gestite. 

I dati statistici vengono generati per default dal componente runtime dell'api gateway attraverso la schedulazione periodica di un thread dedicato.

In ambienti di produzione è consigliato spostare l'attività di generazione delle statistiche su un componente dedicato in modo da non gravare il costo sui nodi run. La disattivazione della generazione delle statistiche sui nodi run deve essere effettuata nel file '/etc/govway/govway_local.properties' come segue:

```
# ================================================
# Generazione Report
...
# Tipo di campionamenti abilitati
org.openspcoop2.pdd.statistiche.generazione.baseOraria.enabled=false
org.openspcoop2.pdd.statistiche.generazione.baseGiornaliera.enabled=false
...
# ================================================

```

Utilizzando docker-compose come esempio di ambiente orchestrato, è possibile utilizzare un docker-compose.yml simile al seguente per database postgresql:

```yaml
version: '2'
 services:
 
  batch_stat_orarie:
    container_name: govway_batch_statistiche_orarie
    image: linkitaly/govway:3.3.13_batch_postgres
    command: 
      - orarie
    environment:
      - GOVWAY_STAT_DB_SERVER=postgres_hostname:5432
      - GOVWAY_STAT_DB_NAME=govwaydb
      - GOVWAY_STAT_DB_USER=govway
      - GOVWAY_STAT_DB_PASSWORD=govway
      - GOVWAY_BATCH_USA_CRON=true
      - GOVWAY_BATCH_INTERVALLO_CRON=5
      - TZ=Europe/Rome

  batch_stat_giornaliere:
    container_name: govway_batch_statistiche_giornaliere
    image: linkitaly/govway:3.3.13_batch_postgres
    command: 
      - giornaliere
    environment:
      - GOVWAY_STAT_DB_SERVER=postgres_hostname:5432
      - GOVWAY_STAT_DB_NAME=govwaydb
      - GOVWAY_STAT_DB_USER=govway
      - GOVWAY_STAT_DB_PASSWORD=govway
      - GOVWAY_BATCH_USA_CRON=true
      - GOVWAY_BATCH_INTERVALLO_CRON=30
      - TZ=Europe/Rome
```

Un esempio di docker-compose per oracle è invece il seguente:

```yaml
version: '2'
 services:
 
   batch_stat_orarie:
    container_name: govway_batch_statistiche_orarie
    image: linkitaly/govway:3.3.13_batch_oracle
    volumes:
       - ~/govway_conf:/etc/govway
       - ~/govway_log:/var/log/govway
       - ~/oracle11g/ojdbc7.jar:/tmp/ojdbc7.jar
    command: 
      - orarie
    environment:
      - GOVWAY_ORACLE_JDBC_PATH=/tmp/ojdbc7.jar
      - GOVWAY_ORACLE_JDBC_URL_TYPE=ServiceName
      - GOVWAY_STAT_DB_SERVER=oracle_hostname:1521
      - GOVWAY_STAT_DB_NAME=govwaydb
      - GOVWAY_STAT_DB_USER=govway
      - GOVWAY_STAT_DB_PASSWORD=govway
      - GOVWAY_BATCH_USA_CRON=true
      - GOVWAY_BATCH_INTERVALLO_CRON=5
      - TZ=Europe/Rome

  batch_stat_giornaliere:
    container_name: govway_batch_statistiche_giornaliere
    image: linkitaly/govway:3.3.13_batch_oracle
    volumes:
       - ~/govway_conf:/etc/govway
       - ~/govway_log:/var/log/govway
       - ~/oracle11g/ojdbc7.jar:/tmp/ojdbc7.jar
    command: 
      - giornaliere
    environment:
      - GOVWAY_ORACLE_JDBC_PATH=/tmp/ojdbc7.jar
      - GOVWAY_ORACLE_JDBC_URL_TYPE=ServiceName
      - GOVWAY_STAT_DB_SERVER=oracle_hostname:1521
      - GOVWAY_STAT_DB_NAME=govwaydb
      - GOVWAY_STAT_DB_USER=govway
      - GOVWAY_STAT_DB_PASSWORD=govway
      - GOVWAY_BATCH_USA_CRON=true
      - GOVWAY_BATCH_INTERVALLO_CRON=30
      - TZ=Europe/Rome
```


I containers vengono avviati con i seguenti comandi:

```console
$ mkdir -p ~/govway_{conf,log}
$ chmod 777 ~/govway_{conf,log}
$ docker-compose up
```

> **_NOTA:_** Negli esempi forniti per l'ambiente docker-compose, non essendo possibile schedulare jobs in maniera orchestrata, è stata abilitata la modalità 'cron' tramite l'abilitazione della variabile 'GOVWAY_BATCH_USA_CRON' e la definizione dell'intervallo di schedulazione del batch in minuti tramite la variabile 'GOVWAY_BATCH_INTERVALLO_CRON'. Su ambienti dove esiste la possibilità di schedulare jobs (es. Cronjobs kubernetes) deve essere disabilitata la variabile 'GOVWAY_BATCH_USA_CRON' o in alternativa non deve essere dichiarata (assume per default il valore false).


## Versione Snapshot

Ogni modifica dei sorgenti attuata sul master del progetto viene validata nell'ambiente di [continuous integration](https://jenkins.link.it/govway/job/GovWay/).
Il processo produce un [installer della versione snapshot](https://jenkins.link.it/govway-testsuite/installer/) scaricabile dall'ambiente di CI.

Vengono inoltre fornite le seguenti immagini per le versioni snapshot:

* [`master`, `master_standalone` (Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`master_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`master_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`master_batch_postgres` (Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
* [`master_batch_oracle` (Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/Dockerfile.govway)
