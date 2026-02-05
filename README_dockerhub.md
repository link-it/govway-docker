<img src="https://www.link.it/wp-content/uploads/2025/01/logo-govway.svg" alt="GovWay Logo" width="200"/>

# Docker Image


## Tags supportati e link ai rispettivi Dockerfile

### 3.4.x

* `3.4.1.p1`, `3.4.1.p1_standalone`, `latest`
* `3.4.1.p1_postgres`
* `3.4.1.p1_run_postgres`
* `3.4.1.p1_manager_postgres`
* `3.4.1.p1_batch_postgres`
* `3.4.1.p1_oracle`
* `3.4.1.p1_run_oracle`
* `3.4.1.p1_manager_oracle`
* `3.4.1.p1_batch_oracle`
* [`Dockerfile`](https://github.com/link-it/govway-docker/blob/gw_3.4.1.p1/govway/tomcat10/Dockerfile.govway)
* `3.4.0`, `3.4.0_standalone`, `latest`
* `3.4.0_postgres`
* `3.4.0_run_postgres`
* `3.4.0_manager_postgres`
* `3.4.0_batch_postgres`
* `3.4.0_oracle`
* `3.4.0_run_oracle`
* `3.4.0_manager_oracle`
* `3.4.0_batch_oracle`
* [`Dockerfile`](https://github.com/link-it/govway-docker/blob/gw_3.4.0/govway/tomcat10/Dockerfile.govway)

### 3.3.x

* `3.3.18`, `3.3.18_standalone` 
* `3.3.18_postgres`
* `3.3.18_run_postgres`
* `3.3.18_manager_postgres`
* `3.3.18_batch_postgres`
* `3.3.18_oracle`
* `3.3.18_run_oracle`
* `3.3.18_manager_oracle`
* `3.3.18_batch_oracle`
* [`Dockerfile`](https://github.com/link-it/govway-docker/blob/gw_3.3.18/govway/tomcat9/Dockerfile.govway)
* `3.3.17`, `3.3.17_standalone` 
* `3.3.17_postgres`
* `3.3.17_run_postgres`
* `3.3.17_manager_postgres`
* `3.3.17_batch_postgres`
* `3.3.17_oracle`
* `3.3.17_run_oracle`
* `3.3.17_manager_oracle`
* `3.3.17_batch_oracle`
* [`Dockerfile`](https://github.com/link-it/govway-docker/blob/gw_3.3.17/govway/tomcat9/Dockerfile.govway)

## Riferimenti al progetto
* [Informazioni sul progetto GovWay](https://govway.org/)
* [Sorgenti GovWay su GitHub](https://github.com/link-it/govway)
* [Progetto Govway-Docker su GitHub](https://github.com/link-it/govway-docker)

## Cosa è GovWay
Dall’esperienza della Porta di Dominio italiana, l’API Gateway conforme alle normative della Pubblica Amministrazione:

* Conformità agli standard di mercato: gestione protocolli standard di mercato, come SOAP 1.1 e 1.2, API restful serializzate in Json o XML o semplici dati binari su Http.
* Conformità alle specifiche italiane per l'interoperabilità: supporto delle nuove linee guida per l'interoperabilità di AGID (ModI) e gestione dei token rilasciati dalla PDND. Viene inoltre assicurata la retrocompatibilità con il protocollo SPCoop, ancora ampiamente adottato per i servizi della PA.
* Conformità alle specifiche per la fatturazione elettronica sul canale SdiCoop.

## Release Notes

- *3.4.1* / *3.3.18*

   - Aggiornato driver jdbc di postgresql alla versione 42.7.8
   - Eliminata esposizione di informazioni sulla versione di Tomcat;
   - Introdotte le variabili 'GOVWAY_SERVICE_PROTOCOL', 'GOVWAY_SERVICE_HOST' e 'GOVWAY_SERVICE_PORT' che consentono di definire l'indirizzamento dei nodi run senza dover definire il file '/etc/govway/govway.nodirun.properties';
   - Introdotta la variabile 'GOVWAY_DB_MAPPING' che consente di definire la distribuzione delle diverse categorie di dati su database distinti;
   - Aggiunta possibilità di modificare i parametri di gestione della memoria usata dalla JVM.
   - Introdotto 'Health Check' per ambiente manager
   - Aggiornato application server di base (Tomcat) alla versione 9.0.111 per la 3.3.18 e alla versione 11.0.13 per la 3.4.1.

- *3.3.17*

   - Aggiornato application server di base (Tomcat) alla versione 9.0.107.
   - Aggiornato driver jdbc di postgresql alla versione 42.7.7

- *3.3.16.p2*

   - Aggiornato application server di base (Tomcat) alla versione 9.0.105.

- Storico completo delle modifiche consultabile nel [ChangeLog](https://github.com/link-it/govway-docker/blob/master/ChangeLog) del progetto [Govway-Docker](https://github.com/link-it/govway-docker/).


## Nomenclatura delle immagini fornite

### Versioni 3.4.2 / 3.3.19 e successive

A partire dalla versione 3.4.2 / 3.3.19, l'immagine Docker è **unica e multi-database**: supporta i database hsql, postgresql, mysql, mariadb e oracle. La scelta del database avviene a runtime tramite la variabile obbligatoria `GOVWAY_DB_TYPE`.

> **_BREAKING CHANGE:_** Aggiornando da una versione precedente è necessario aggiungere la variabile d'ambiente `GOVWAY_DB_TYPE` alla configurazione del container (es. docker-compose.yaml o comando docker run). I valori ammessi sono: hsql, postgresql, mysql, mariadb, oracle.

- **standalone** (GOVWAY_DB_TYPE=hsql): fornisce un ambiente di prova di GovWay funzionante dove i dati di configurazione e tracciamento vengono mantenuti su un database HSQL interno al container;

- **orchestrate** (GOVWAY_DB_TYPE=postgresql|mysql|mariadb|oracle): fornisce un'installazione che consente di avere i dati di configurazione e tracciamento su un database esterno, gestito esternamente o su ambienti orchestrati (Es. Kubernetes, OpenShift).

Esistono ulteriori immagini che suddividono i componenti applicativi tra componenti di runtime e componenti dedicati alla gestione e il monitoraggio. Una suddivisione dei componenti consente di attuare una scalabilità dei nodi run proporzionata alla mole di richieste che devono essere gestite dall'api gateway:

- **run**: contiene solamente il componente runtime di api gateway;

- **manager**: contiene solamente le console e i servizi API di configurazione e monitoraggio.

### Versioni precedenti alla 3.4.2 / 3.3.19

Nelle versioni precedenti, venivano fornite immagini separate per ogni tipo di database:

- **standalone**: ambiente con database HSQL interno al container;

- **postgres** o **oracle**: immagine specifica per database postgresql o oracle esterno;

- **run_postgres** o **run_oracle**: componente runtime per database postgresql o oracle;

- **manager_postgres** o **manager_oracle**: console e servizi API per database postgresql o oracle.

### Ambienti run e manager

Le console disponibili nell’ambiente manager necessitano di accedere ad alcuni servizi esposti dai nodi run, utilizzati per il monitoraggio e la gestione distribuita:

- servizio 'check': consente di monitorare lo stato del servizio dei nodi run; è possibile invocare il contesto "/govway/check" di un qualsiasi nodo run (riferendo l'endpoint di esposizione del servizio dei nodi run) o un servizio fornito dal container;

- servizio 'proxy': consente di inviare un comando ad ogni nodo run attivo; deve essere indirizzato il servizio "/govway/proxy" di un qualsiasi nodo attivo.

L’ambiente manager accede ai due servizi tramite le seguenti URL di default:

- ${GOVWAY_SERVICE_PROTOCOL}://${GOVWAY_SERVICE_HOST}:${GOVWAY_SERVICE_PORT}/govway/check
- ${GOVWAY_SERVICE_PROTOCOL}://${GOVWAY_SERVICE_HOST}:${GOVWAY_SERVICE_PORT}/govway/proxy

Se non ridefinite, le variabili d’ambiente assumono i seguenti valori predefiniti:

- GOVWAY_SERVICE_PROTOCOL = http
- GOVWAY_SERVICE_HOST = 127.0.0.1
- GOVWAY_SERVICE_PORT = 8082

In alternativa è possibile ridefinire completamente l’indirizzamento dei servizi dei nodi run tramite il file di configurazione
"/etc/govway/govway.nodirun.properties", come nell’esempio seguente:

```
# ===================================================================
# Indirizzamento servizi dei nodi 'run' 
# Servizio 'proxy'
GovWay.remoteAccess.url=http://<service-name:8082>/govway/proxy
# Servizio 'check'
GovWay.remoteAccess.checkStatus.url=http://<service-name>:8082/govway/check
# ===================================================================
```

### Health Check

I seguenti contesti possono essere utilizzati come health check:

- run: /govway/check
- manager: /govwayMonitor/check

## Avviare l'immagine standalone

Eseguire il _run_ dell'immagine:

> **_NOTA:_** la variabile 'GOVWAY_DEFAULT_ENTITY_NAME' consente di indicare il nome del soggetto operativo attivo sul dominio gestito attraverso GovWay.

```console
$ docker run \
  -e GOVWAY_DB_TYPE=hsql \
  -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
  -e GOVWAY_POP_DB_SKIP=false \
  -e TZ=Europe/Rome \
linkitaly/govway
```

I servizi e le interfacce web di GovWay sono accessibili sia su protocollo HTTP, che su protocollo AJP sulle porte 808* e 8009 rispettivamente (nella sezione 'Informazioni di Base' vengono fornite maggiori informazioni a riguardo):

```console
$ docker run \
 -e GOVWAY_DB_TYPE=hsql \
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
- il database HSQL situato in **/opt/hsqldb-2.7.4/hsqldb/database**.

Si possono rendere persistenti i file sopra indicati montando un volume per ogni directory indicata:

```console
$ mkdir ~/govway_conf
$ mkdir ~/govway_log
$ mkdir ~/govway_db
$ docker run \
 -e GOVWAY_DB_TYPE=hsql \
 -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
 -e GOVWAY_POP_DB_SKIP=false \
 -e TZ=Europe/Rome \
 -p 8080:8080 \
 -p 8081:8081 \
 -p 8082:8082 \
 -p 8009:8009 \
 -v ~/govway_conf:/etc/govway \
 -v ~/govway_log:/var/log/govway \
 -v ~/govway_db:/opt/hsqldb-2.7.4/hsqldb/database \
linkitaly/govway
```
> **_NOTA:_** abilitando la variabile 'GOVWAY_POP_DB_SKIP' non verra effettuata l'inizializzazione della base dati.


## Avviare una delle immagini orchestrate

Utilizzando docker-compose come esempio di ambiente orchestrato, è possibile utilizzare un docker-compose.yml simile al seguente per database postgresql (nella dir ~/postgresql/jdbc-driver deve essere presente il driver jdbc):

> **_NOTA:_** la variabile 'GOVWAY_DEFAULT_ENTITY_NAME' consente di indicare il nome del soggetto operativo attivo sul dominio gestito attraverso GovWay.

```yaml
version: '2'
services:
  govway:
    container_name: govway
    image: linkitaly/govway:3.4.1.p1
    ports:
        - 8080:8080
        - 8081:8081
        - 8082:8082
        - 8009:8009
    volumes:
        - ~/govway_conf:/etc/govway
        - ~/govway_log:/var/log/govway
        - ~/postgresql/jdbc-driver:/tmp/jdbc-driver
    environment:
        - TZ=Europe/Rome
        - GOVWAY_DB_TYPE=postgresql
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DS_JDBC_LIBS=/tmp/jdbc-driver
        - GOVWAY_DB_SERVER=postgres_hostname:5432
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
        - GOVWAY_POP_DB_SKIP=true
```

Un esempio di docker-compose per oracle è invece il seguente (nella dir ~/oracle11g/jdbc-driver deve essere presente il driver jdbc):

```yaml
version: '2'
services:
  govway:
    container_name: govway
    image: linkitaly/govway:3.4.1.p1
    ports:
        - 8080:8080
        - 8081:8081
        - 8082:8082
        - 8009:8009
    volumes:
        - ~/govway_conf:/etc/govway
        - ~/govway_log:/var/log/govway
        - ~/oracle11g/jdbc-driver:/tmp/jdbc-driver
    environment:
        - TZ=Europe/Rome
        - GOVWAY_DB_TYPE=oracle
        - GOVWAY_DEFAULT_ENTITY_NAME=Ente
        - GOVWAY_DS_JDBC_LIBS=/tmp/jdbc-driver
        - GOVWAY_ORACLE_JDBC_URL_TYPE=SERVICENAME
        - GOVWAY_DB_SERVER=oracle_hostname:1521
        - GOVWAY_DB_NAME=govwaydb
        - GOVWAY_DB_USER=govway
        - GOVWAY_DB_PASSWORD=govway
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
- in una immagine standalone il database HSQL è situato in **/opt/hsqldb-2.7.4/hsqldb/database**.

si possono rendere queste location persistenti, montando dei volumi su queste directory come mostrato negli esempi delle sezioni precedenti.

### Servizi attivi

I servizi attivi all'interno dell'immagine sono in ascolto sia in protocollo _**AJP**_ sulla porta **8009** sia in _**HTTP**_ su 3 porte in modo da gestire il traffico su ogni porta, con un listener dedicato:
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

Il contesto di accesso ai servizi dell'API gateway per le erogazioni di API:
```
 http://<indirizzo IP>:8080/govway/
```

Il contesto di accesso ai servizi dell'API gateway per le fruizioni di API:
```
 http://<indirizzo IP>:8081/govway/
```

### Script SQL di inizializzazione della BaseDati

All'avvio del container, sia in modalità standalone che con immagini orchestrate, vengono eseguite delle verifiche sul database per assicurarne la raggiungibilità ed il corretto popolamento; in caso venga riconosciuto un database non inizializzato vengono utilizzati gli scripts SQL interni per effettuare l'inizializzazione a meno che la variabile 'GOVWAY_POP_DB_SKIP' risulta abilitata.

Per esaminare gli script SQL di inizializzazione o utilizzarli manualmente è possibile recuperarli dall'immagine in una delle directory standard **/opt/hsql**, **/opt/postgresql**, **/opt/mysql**, **/opt/mariadb** o **/opt/oracle**. Ad esempio per estrarre gli script SQL per PostgreSQL è possibile utilizzare il comando:

```shell
CONTAINER_ID=$(docker run -d -e GOVWAY_DEFAULT_ENTITY_NAME=Ente -e GOVWAY_DB_TYPE=postgresql linkitaly/govway:3.4.1.p1 initsql);
docker wait ${CONTAINER_ID};
docker cp ${CONTAINER_ID}:/opt/postgresql .;
docker rm ${CONTAINER_ID}
```

> **_NOTA:_** Quando più categorie di dati di GovWay (ad esempio Tracciamento, Statistiche e Configurazione) condividono lo stesso database, gli script SQL generati possono includere tabelle duplicate, provocando errori durante l’esecuzione manuale. Per evitare questo problema, è possibile utilizzare la variabile **GOVWAY_DB_MAPPING**, che consente di definire la distribuzione delle diverse categorie di dati su database distinti. Le modalità di configurazione sono descritte nella sezione [Condivisione Database tra Categorie](https://github.com/link-it/govway-docker#condivisione-database-tra-categorie) della documentazione del progetto [Govway-Docker](https://github.com/link-it/govway-docker).

## Aggiornamento di Versione

Un upgrade richiede l'aggiornamento della base dati. 

Serve inoltre una verifica dei diritti utente se si proviene da una versione precedente alla 3.3.16.b1, come descritto nella successiva sezione.

### Upgrade di una versione precedente alla v3.3.16.b1

Nel caso siano stati utilizzati dei volumi esterni è necessario gestire il cambio di utente che è avvenuto in seguito alla modifica del sistema operativo di base da Ubuntu 22 LTS (Jammy) a Alpine 3.21.3. Questo comporta aggiornare i diritti associati alle directory montate utilizzando l'id-utente '100' e l'id-gruppo '101' di tomcat; ad esempio:

  ```
    chown -R 100:101 ~/govway_conf
    chown -R 100:101 ~/govway_log
    chown -R 100:101 ~/govway_db
  ```

### Upgrade di una versione precedente alla v3.3.15 fino alla v3.3.16

Nel caso siano stati utilizzati dei volumi esterni è necessario gestire il cambio di utente che è avvenuto in seguito alla modifica di application server di base da wildfly 26.1.3 a tomcat 9.0.x. Questo comporta aggiornare i diritti associati alle directory montate utilizzando l'id-utente '999' di tomcat; ad esempio:


  ```
    chown -R 999:999 ~/govway_conf
    chown -R 999:999 ~/govway_log
    chown -R 999:999 ~/govway_db
  ```

### Ambiente orchestrato

Se è stato utilizzato un docker-compose su ambiente orchestrato (postgresql o oracle) o un'immagine standalone con database montato su un volume esterno, per effettuare l'upgrade è necessario seguire i seguenti step:

- fermare ed eliminare il container contenente la precedente versione;

- aggiornare la base dati come indicato in [README.update](https://github.com/link-it/govway/blob/master/resources/sql_upgrade/README.update);

  - nel caso di un aggiornamento da una versione precedente alla 3.3.15, è necessario applicare i seguenti script SQL aggiuntivi sulla base dati, a causa della modifica dell'application server di base da WildFly a Tomcat:
  
    ```
    update registri set location='java:/comp/env/org.govway.datasource.console';
    update audit_appender_prop set value='java:/comp/env/org.govway.datasource.console' where name='datasource';
    ```
    
- riferire la nuova versione all'interno del docker-compose;

- riavviare il docker-compose. 

> **_NOTA:_** una volta applicate le patch di upgrade descritte in [README.update](https://github.com/link-it/govway/blob/master/resources/sql_upgrade/README.update) la base dati non risulta più compatibile con la precedente versione del software. Si consiglia di effettuare un backup prima di procedere con l'upgrade in modo da poter effettuare un eventuale downgrade di versione.


### Standalone

Nel caso di versione standalone in cui il database non sia stato montato su un volume esterno, è sufficiente avviare la nuova versione dell'immagine.

> **_NOTA:_** i dati contenuti all'interno del precedente container verranno persi.



## Ambienti batch

La console di Monitoraggio mette a disposizione informazioni statistiche aggregate, elaborate su base periodica, relative alle transazioni gestite. Questi dati consentono un’analisi sintetica e continuativa dell’andamento del sistema.

In aggiunta, è previsto un campionamento specifico dedicato alla generazione di report in formato CSV, conformi agli standard previsti dalla Piattaforma Digitale Nazionale Dati (PDND), con relativa gestione della pubblicazione attraverso le API di Interoperabilità.

Sia i dati statistici che la pubblicazione dei report PDND vengono gestiti per default dal componente runtime dell'api gateway attraverso la schedulazione periodica di thread dedicati.

In ambienti di produzione è consigliato spostare l'attività di generazione delle statistiche su un componente dedicato in modo da non gravare il costo sui nodi run. La disattivazione della generazione delle statistiche sui nodi run deve essere effettuata nel file '/etc/govway/govway_local.properties' come segue:

```
# ================================================
# Generazione Report
...
# Tipo di campionamenti abilitati
org.openspcoop2.pdd.statistiche.generazione.baseOraria.enabled=false
org.openspcoop2.pdd.statistiche.generazione.baseGiornaliera.enabled=false
org.openspcoop2.pdd.statistiche.pdnd.tracciamento.generazione.enabled=false
org.openspcoop2.pdd.statistiche.pdnd.tracciamento.pubblicazione.enabled=false
...
# ================================================

```

Utilizzando docker-compose come esempio di ambiente orchestrato, è possibile utilizzare un docker-compose.yml simile al seguente per database postgresql (nella dir ~/postgresql/jdbc-driver deve essere presente il driver jdbc):

```yaml
version: '2'
services:

  batch_stat_orarie:
    container_name: govway_batch_statistiche_orarie
    image: linkitaly/govway:3.3.17_batch
    volumes:
       - ~/govway_log:/var/log/govway
       - ~/postgresql/jdbc-driver:/tmp/jdbc-driver
    command:
      - orarie
    environment:
      - GOVWAY_DB_TYPE=postgresql
      - GOVWAY_DS_JDBC_LIBS=/tmp/jdbc-driver
      - GOVWAY_STAT_DB_SERVER=postgres_hostname:5432
      - GOVWAY_STAT_DB_NAME=govwaydb
      - GOVWAY_STAT_DB_USER=govway
      - GOVWAY_STAT_DB_PASSWORD=govway
      - GOVWAY_BATCH_USA_CRON=true
      - GOVWAY_BATCH_INTERVALLO_CRON=5
      - TZ=Europe/Rome

  batch_stat_giornaliere:
    container_name: govway_batch_statistiche_giornaliere
    image: linkitaly/govway:3.4.1.p1_batch
    command:
      - giornaliere
    environment:
      - ... come esempio 'batch_stat_orarie' ...

  batch_generazione_report_pdnd:
    container_name: govway_batch_generazione_report_pdnd
    image: linkitaly/govway:3.4.1.p1_batch
    command:
      - generaReportPDND
    environment:
      - ... come esempio 'batch_stat_orarie' ...

  batch_pubblicazione_report_pdnd:
    container_name: govway_batch_pubblicazione_report_pdnd
    image: linkitaly/govway:3.4.1.p1_batch
    command:
      - pubblicaReportPDND
    environment:
      - ... come esempio 'batch_stat_orarie' ...
```

Un esempio di docker-compose per oracle è invece il seguente (nella dir ~/oracle11g/jdbc-driver deve essere presente il driver jdbc):

```yaml
version: '2'
services:

  batch_stat_orarie:
    container_name: govway_batch_statistiche_orarie
    image: linkitaly/govway:3.4.1.p1_batch
    volumes:
       - ~/govway_log:/var/log/govway
       - ~/oracle11g/jdbc-driver:/tmp/jdbc-driver
    command:
      - orarie
    environment:
      - GOVWAY_DB_TYPE=oracle
      - GOVWAY_DS_JDBC_LIBS=/tmp/jdbc-driver
      - GOVWAY_ORACLE_JDBC_URL_TYPE=SERVICENAME
      - GOVWAY_STAT_DB_SERVER=oracle_hostname:1521
      - GOVWAY_STAT_DB_NAME=govwaydb
      - GOVWAY_STAT_DB_USER=govway
      - GOVWAY_STAT_DB_PASSWORD=govway
      - GOVWAY_BATCH_USA_CRON=true
      - GOVWAY_BATCH_INTERVALLO_CRON=5
      - TZ=Europe/Rome

  batch_stat_giornaliere:
    container_name: govway_batch_statistiche_giornaliere
    image: linkitaly/govway:3.4.1.p1_batch
    volumes:
       - ~/govway_conf:/etc/govway
       - ~/govway_log:/var/log/govway
       - ~/oracle11g/jdbc-driver:/tmp/jdbc-driver
    command:
      - giornaliere
    environment:
      - ... come esempio 'batch_stat_orarie' ...

  batch_generazione_report_pdnd:
    container_name: govway_batch_generazione_report_pdnd
    image: linkitaly/govway:3.4.1.p1_batch
    volumes:
       - ~/govway_conf:/etc/govway
       - ~/govway_log:/var/log/govway
       - ~/oracle11g/jdbc-driver:/tmp/jdbc-driver
    command:
      - generaReportPDND
    environment:
      - ... come esempio 'batch_stat_orarie' ...

  batch_pubblicazione_report_pdnd:
    container_name: govway_batch_pubblicazione_report_pdnd
    image: linkitaly/govway:3.4.1.p1_batch
    volumes:
       - ~/govway_conf:/etc/govway
       - ~/govway_log:/var/log/govway
       - ~/oracle11g/jdbc-driver:/tmp/jdbc-driver
    command:
      - pubblicaReportPDND
    environment:
      - ... come esempio 'batch_stat_orarie' ...

```


I containers vengono avviati con i seguenti comandi:

```console
$ mkdir -p ~/govway_{conf,log}
$ chmod 777 ~/govway_{conf,log}
$ docker-compose up
```

> **_NOTA:_** Negli esempi forniti per l'ambiente docker-compose, non essendo possibile schedulare jobs in maniera orchestrata, è stata abilitata la modalità 'cron' tramite l'abilitazione della variabile 'GOVWAY_BATCH_USA_CRON' e la definizione dell'intervallo di schedulazione del batch in minuti tramite la variabile 'GOVWAY_BATCH_INTERVALLO_CRON'. Su ambienti dove esiste la possibilità di schedulare jobs (es. Cronjobs kubernetes) deve essere disabilitata la variabile 'GOVWAY_BATCH_USA_CRON' o in alternativa non deve essere dichiarata (assume per default il valore false).


## Versione Snapshot

### 3.4.x

Ogni modifica dei sorgenti attuata sul branch '3.4.x' del progetto viene validata nell'ambiente di [continuous integration](https://jenkins.link.it/govway4/job/GovWay/).
Il processo produce un [installer della versione snapshot](https://jenkins.link.it/govway4-testsuite/installer/) scaricabile dall'ambiente di CI.

Vengono inoltre fornite le seguenti immagini per le versioni snapshot [(Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/tomcat10/Dockerfile.govway):

* `master4`
* `master4_batch`

> **_ATTENZIONE:_** I tag precedenti (`master4_standalone`, `master4_postgres`, `master4_oracle`, `master4_batch_postgres`, `master4_batch_oracle`) non verranno più aggiornati e punteranno a versioni obsolete.

### 3.3.x

Ogni modifica dei sorgenti attuata sul master del progetto viene validata nell'ambiente di [continuous integration](https://jenkins.link.it/govway/job/GovWay/).
Il processo produce un [installer della versione snapshot](https://jenkins.link.it/govway-testsuite/installer/) scaricabile dall'ambiente di CI.

Vengono inoltre fornite le seguenti immagini per le versioni snapshot [(Dockerfile)](https://github.com/link-it/govway-docker/blob/master/govway/tomcat9/Dockerfile.govway):

* `master`
* `master_batch`

> **_ATTENZIONE:_** I tag precedenti (`master_standalone`, `master_postgres`, `master_oracle`, `master_batch_postgres`, `master_batch_oracle`) non verranno più aggiornati e punteranno a versioni obsolete.
