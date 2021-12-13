# Immagine docker per GovWay

Questo progetto fornisce tutto il necessario per produrre un'ambiente di prova GovWay funzionante, containerizzato in formato Docker. L'ambiente consente di produrre immagini in due modalità:
- **standalone** : in questa modalità l'immagine contiene oltre al gateway anche un database HSQL con persistenza su file, dove vengongono memorizzate le configurazioni e le informazioni elaborate durante l'esercizio del gateway.
- **orchestrate** : in questa modalità l'immagine viene preparata in modo da collegarsi ad un database esterno

## Build immagine Docker
Per semplificare il più possibile la preparazione dell'ambiente, sulla root del progetto è presente uno script di shell che si occupa di prepare il buildcontext e di avviare il processo di build con tutti gli argomenti necessari. 
Lo script può essere avviato senza parametri per ottenere il build dell'immagine di default, ossia una immagine in modalità standalone realizzata a partire dalla release binaria disponibile su GitHub.
Lo script di build consente did personalizzare l'immagine prodotta, impostando opportunamente i parametri, come descritti qui di seguito:

```console
Usage build_image.sh [ -t <repository>:<tagname> | <Installer Sorgente> | <Personalizzazioni> | <Avanzate> | -h ]

Options
-t <TAG>       : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
                 NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-h             : Mostra questa pagina di aiuto

Installer Sorgente:
-v <VERSIONE>  : Imposta la versione dell'installer binario da utilizzare per il build (default: 3.3.5)
-l <FILE>      : Usa un'installer binario sul filesystem locale (incompatibile con -j)
-j             : Usa l'installer prodotto dalla pipeline jenkins https://jenkins.link.it/govway/risultati-testsuite/installer/govway-installer-<version>.tgz

Personalizzazioni:
-d <TIPO>      : Prepara l'immagine per essere utilizzata su un particolare database  (valori: [ hsql, postgresql, oracle] , default: hsql)
-a <TIPO>      : Imposta quali archivi inserire nell'immmagine finale (valori: [runtime , manager, all] , default: all)
-e <PATH>      : Imposta il path interno utilizzato per i file di configurazione di govway 
-f <PATH>      : I posta il path interno utilizzato per i log di govway

Avanzate:
-i <FILE>      : Usa il template ant.installer.properties indicato per la generazione degli archivi dall'installer
-r <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di runtime
-m <DIRECTORY> : Inserisce il contenuto della directory indicata, tra i contenuti custom di manager
-w <DIRECTORY> : Esegue tutti gli scripts widlfly contenuti nella directory indicata
-o <DIRECTORY> : Utilizza il driver JDBC Oracle contenuto dentro la directory per configurare l'immagine (il file viene cancellato al termine)

```

## Avvio immagine Docker

Una volta eseguito il build dell'immagine tramite lo script fornito, l'immagine puo essere eseguita con i normali comandi di run docker:
```shell
./build_image.sh 
docker run \
  -v ~/govway_log:/var/log/govway -v ~/govway_conf:/etc/govway \
  -e GOVWAY_POP_DB_SKIP=false
  -p 8080:8080 \
  -p 8081:8081 \
  -p 8082:8082 \
linkitaly/govway:3.3.5

```

In modalità orchestrate al termine delle operazioni di build, lo script predispone uno scenario di test avviabile con docker-compose, all'interno della directory **"compose"**; lo scenario di test può quindi essere avviato come segue:

```
./build_image.sh -d postgresql
cd compose
docker-compose up
```

Sotto la directory compose vengono create le sottodirectories **govway_conf** e **govway_log**, su cui il container montera' i path _**/etc/govway**_ ed _**/var/log/govway**_  rispettivamente.
L'accesso è previsto in protocollo HTTP sulle porte _**8080, 8081, 8082**_ .

## Informazioni di Base

A prescindere dalla modalità di costruzione dell'immagine, vengono utilizzati i seguenti path:
- **/etc/govway** path le properties di configurazione (riconfigurabile al momento del build). 
- **/var/log/govway** path dove vengono scritti i files di log (riconfigurabile al momento del build).

Se l'immagine è stata prodotta in modalità standalone: 
- **/opt/hsqldb-2.6.1/hsqldb/database** database interno HSQL 

si possono rendere queste location persistenti, montando devi volumi su queste directory.
 

All'avvio del container, sia in modalià standalone che in modaliatà orchestrate, vengono eseguite delle verifiche sul database per assicurarne la raggiungibilità ed il corretto popolamento; in caso venga riconosciuto che il database non è popolato, vengono utilizzatti gli scripts SQL interni, per avviare l'inizializzazione.
Se si vuole esaminare gli script o utilizzarli manualmente, è possibile recuperarli dall'immagine in una delle directory standard  **/opt/hsql**, **/opt/postgresql** o **/opt/oracle**.

```shell
CONTAINER_ID=$(docker create linkitaly/govway:3.3.5_postgres)
docker cp ${CONTAINER_ID}:/opt/postgresql .
```

Le immagini prodotte utilizzano come application server ospite WildFly 18.0.1.Final, in ascolto sia in protocollo _**HTTP**_ sulle porte **8080**, **8081** e **8082** sia in _**AJP**_ sulla porta **8009**; queste porte sono esposte dal container e per accedere ai servizi dall'esterno, si devono pubblicare al momento dell'avvio del immagine.  Le interfacce web di monitoraggio configurazione sono quindi disponibili sulle URL:
```
 http://<indirizzo IP>:8080/govwayConsole/
 http://<indirizzo IP>:8080/govwayMonitor/
```
L'account di default per l'interfaccia **govwayConsole** è:
 * username: amministratore
 * password: 123456

L'account di default per l'interfaccia **govwayMonitor** è:
 * username: operatore
 * password: 123456

Il contesto di accesso ai aservizi dell`API gateway è invece il seguente:
```
 http://<indirizzo IP>:8080/govway/
```

## Personalizzazioni
Attraverso l'impostazione di alcune variabili d'ambiente note è possibile personalizzare alcuni aspetti del funzionamento del container. Le variabili supportate al momento sono queste:

### Controlli all'avvio del container

A runtime il container esegue i controlli di: raggiungibilita del database, di popolamento del database e di avvio di govway. Questi controlli possono essere abilitati o meno impostando le seguenti variabili d'ambiente:

* GOVWAY_LIVE_DB_CHECK_SKIP: Salta il controllo di raggiungibilità dei server database allo startup (default: FALSE)

* GOVWAY_READY_DB_CHECK_SKIP: Salta il controllo di popolamento dei database allo startup (default: FALSE)

* GOVWAY_STARTUP_CHECK_SKIP: Salta il controllo di avvio di govway allo startup (default: FALSE)

* GOVWAY_POP_DB_SKIP: Salta il popolamento automatico delle tabelle (default: TRUE)

E' possibile personalizzare il ciclo di controllo di raggiungibilità dei server database impostando le seguenti variabili d'ambiente:
* GOVWAY_LIVE_DB_CHECK_FIRST_SLEEP_TIME: tempo di attesa, in secondi, prima di effettuare la prima verifica (default: 0)
* GOVWAY_LIVE_DB_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un tentativo di connessione faallito ed il successivo (default: 2)
* GOVWAY_LIVE_DB_CHECK_MAX_RETRY: Numero massimo di tentativi di connessione (default: 30)
* GOVWAY_LIVE_DB_CHECK_CONNECT_TIMEOUT: Timeout di connessione al server, in secondi (default: 5)


E' possibile personalizzare il ciclo di controllo di popolamento dei server database impostando le seguenti variabili d'ambiente:
* GOVWAY_READY_DB_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un tentativo di connessione faallito ed il successivo (default: 2)
* GOVWAY_READY_DB_CHECK_MAX_RETRY: Numero massimo di tentativi di connessione (default: 5)


E' possibile personalizzare il ciclo di controllo di avvio di govway impostando le seguenti variabili d'ambiente:
* GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME: tempo di attesa, in secondi, prima di effettuare il primo controllo (default: 20)
* GOVWAY_STARTUP_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un controllo fallito ed il successivo  (default: 5)
* GOVWAY_STARTUP_CHECK_MAX_RETRY: Numero massimo di controlli effettuati (default: 60)

### Connessione a database esterni 

* GOVWAY_DB_SERVER: nome dns o ip address del server database (obbligatorio in modalita orchestrate)
* GOVWAY_DB_NAME: Nome del database (obbligatorio in modalita orchestrate)
* GOVWAY_DB_USER: username da utiliizare per l'accesso al database (obbligatorio in modalita orchestrate)
* GOVWAY_DB_PASSWORD: password di accesso al database (obbligatorio in modalita orchestrate)

Se la configurazione lo richiede è possibile suddividere i dati prodotti o utilizzati da govway, su piu' database, a seconda della categoria di dati contenuti.
Le categorie di dati gestite sono:  CONFIGURAZIONE, TRACCIAMENTO e STATISTICHE.

E' possibile quindi, aggiungere puntamenti ai database, indicando in aggiunta al set di variabili indicato in precedenza, uno o piu di quelli indicati di seguito:  

CONFIGURAZIONE
* GOVWAY_CONF_DB_SERVER (default: GOVWAY_DB_SERVER)
* GOVWAY_CONF_DB_NAME (default: GOVWAY_DB_NAME)
* GOVWAY_CONF_DB_USER (default: GOVWAY_DB_USER)
* GOVWAY_CONF_DB_PASSWORD (default: GOVWAY_DB_PASSWORD)

STATISTICHE
* GOVWAY_STAT_DB_SERVER (default: GOVWAY_DB_SERVER)
* GOVWAY_STAT_DB_NAME (default: GOVWAY_DB_NAME)
* GOVWAY_STAT_DB_USER (default: GOVWAY_DB_USER)
* GOVWAY_STAT_DB_PASSWORD (default: GOVWAY_DB_PASSWORD)

TRACCIAMENTO
* GOVWAY_TRAC_DB_SERVER (default: GOVWAY_DB_SERVER)
* GOVWAY_TRAC_DB_NAME (default: GOVWAY_DB_NAME)
* GOVWAY_TRAC_DB_USER (default: GOVWAY_DB_USER)
* GOVWAY_TRAC_DB_PASSWORD (default: GOVWAY_DB_PASSWORD)

#### Connessione a database Oracle ####
Quando ci si connette ad un databse esterno Oracle devono essere indicate anche le seguenti variabili d'ambiente


* GOVWAY_ORACLE_JDBC_PATH: path sul filesystem del container, al driver jdbc da utilizzare (obbligatorio: deve essere obbligatoriamente montato come volume all'avvio)
* GOVWAY_ORACLE_JDBC_URL_TYPE: indica se connettersi ad un SID o ad un ServiceName Oracle (defalt: SERVICENAME)

### Pooling connessioni

* GOVWAY_MAX_POOL: Numero massimo di connessioni stabilite(default: 50)
* GOVWAY_MIN_POOL: Numero minimo di connessioni stabilite (default: 2)
* GOVWAY_DS_BLOCKING_TIMEOUT: Tempo di attesa, im millisecondi, per una connessione libera dal pool (default: 30000)
* GOVWAY_DS_IDLE_TIMEOUT: Tempo trascorso, in minuti, prima di eliminare una connessione dal pool per inattivita (default: 5)
* GOVWAY_DS_CONN_PARAM: parametri JDBC aggiuntivi (default: vuoto)
* GOVWAY_DS_PSCACHESIZE: dimensione della cache usata per le prepared statements (default: 20)

Se è stata utilizzata la suddivisione dei dati su piu' database, è possibile in aggiunta al set di variabili indicato in precedenza, fornire uno o più di quelli indicati di seguito:  

CONFIGURAZIONE
* GOVWAY_CONF_MAX_POOL (default: 10)
* GOVWAY_CONF_MIN_POOL (default: 2)
* GOVWAY_CONF_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_CONF_DS_CONN_PARAM (default: vuoto)
* GOVWAY_CONF_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_CONF_DS_PSCACHESIZE (default: 20)

STATISTICHE
* GOVWAY_STAT_MAX_POOL (default: 5)
* GOVWAY_STAT_MIN_POOL (default: 1)
* GOVWAY_STAT_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_STAT_DS_CONN_PARAM (default: vuoto)
* GOVWAY_STAT_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_STAT_DS_PSCACHESIZE (default: 20)

TRACCIAMENTO
* GOVWAY_TRAC_MAX_POOL (default: 50)
* GOVWAY_TRAC_MIN_POOL (default: 2)
* GOVWAY_TRAC_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_TRAC_DS_CONN_PARAM (default: vuoto)
* GOVWAY_TRAC_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_TRAC_DS_PSCACHESIZE (default: 20)


