# Immagine docker per GovWay

Questo progetto fornisce tutto il necessario per produrre un'ambiente di prova GovWay funzionante, containerizzato in formato Docker. L'immagine prodotta è **unica e multi-database**: supporta tutti i database (hsql, postgresql, mysql, mariadb, oracle, sqlserver) e la scelta del database avviene a runtime tramite la variabile obbligatoria `GOVWAY_DB_TYPE`.

L'ambiente consente di utilizzare l'immagine in due modalità:
- **standalone** : in questa modalità l'immagine utilizza un database HSQL interno con persistenza su file, dove vengono memorizzate le configurazioni e le informazioni elaborate durante l'esercizio del gateway.
- **orchestrate** : in questa modalità l'immagine viene configurata per collegarsi ad un database esterno (postgresql, mysql, mariadb, oracle, sqlserver)

## Build immagine Docker
Per semplificare il più possibile la preparazione dell'ambiente, sulla root del progetto è presente lo script **build_image.sh** che si occupa di preparare il buildcontext e di avviare il processo di build con tutti gli argomenti necessari.

Lo script può essere avviato senza parametri per ottenere il build dell'immagine di default, realizzata a partire dalla release binaria disponibile su GitHub. L'immagine prodotta è unica e multi-database; la scelta del database (standalone con HSQL o orchestrate con database esterno) avviene a runtime.

Eseguendo lo script con il parametro '-h' è possibile conoscere i parametri di personalizzazione esistenti.

## Avvio immagine Docker

Una volta eseguito il build dell'immagine tramite lo script **build_image.sh**, l'immagine può essere eseguita con i normali comandi di run docker.

### Avvio in modalità standalone (HSQL)
```shell
docker run \
  -v ~/govway_log:/var/log/govway -v ~/govway_conf:/etc/govway \
  -e GOVWAY_DB_TYPE=hsql \
  -e GOVWAY_POP_DB_SKIP=false \
  -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
  -p 8080:8080 \
  -p 8081:8081 \
  -p 8082:8082 \
linkitaly/govway:3.4.3
```

### Avvio in modalità orchestrate (database esterno)
```shell
docker run \
  -v ~/govway_log:/var/log/govway -v ~/govway_conf:/etc/govway \
  -v ./postgresql-42.7.5.jar:/tmp/postgresql-42.7.5.jar \
  -e GOVWAY_DB_TYPE=postgresql \
  -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
  -e GOVWAY_DB_SERVER=pg-server \
  -e GOVWAY_DB_NAME=govwaydb \
  -e GOVWAY_DB_USER=govway \
  -e GOVWAY_DB_PASSWORD=govway \
  -e GOVWAY_DS_JDBC_LIBS=/tmp \
  -p 8080:8080 \
  -p 8081:8081 \
  -p 8082:8082 \
linkitaly/govway:3.4.3
```

### Scenari di test con docker-compose

Al termine delle operazioni di build, lo script predispone degli scenari di test avviabili con docker-compose, nelle seguenti directory:
- **compose/postgresql/** : scenario con database PostgreSQL
- **compose/mysql/** : scenario con database MySQL
- **compose/mariadb/** : scenario con database MariaDB
- **compose/oracle/** : scenario con database Oracle
- **compose/sqlserver/** : scenario con database SQL Server

Per utilizzare uno scenario con database esterno è necessario copiare il driver JDBC appropriato nella directory corrispondente:
- PostgreSQL: `postgresql-42.7.5.jar`
- MySQL: `mysql-connector-java-8.0.29.jar`
- MariaDB: `mariadb-java-client-3.0.6.jar`
- Oracle: `ojdbc10.jar`
- SQL Server: `mssql-jdbc-*.jar`

Esempio di avvio con PostgreSQL:
```
cp postgresql-42.7.5.jar compose/postgresql/
cd compose/postgresql
docker compose up
```

Sotto la directory compose vengono create le sottodirectories **govway_conf** e **govway_log**, su cui il container montera' i path _**/etc/govway**_ ed _**/var/log/govway**_  rispettivamente.
L'accesso è previsto in protocollo HTTP sulle porte _**8080, 8081, 8082**_ (le stesse porte sono disponibili anche in HTTPS su _**8443, 8444, 8445**_, vedi [Configurazione HTTPS/TLS](#configurazione-httpstls)).

## Informazioni di Base

### File interni all'immagine

A prescindere dalla modalità di costruzione dell'immagine, vengono utilizzati i seguenti path:
- **/etc/govway** path le properties di configurazione (riconfigurabile al momento del build). 
- **/var/log/govway** path dove vengono scritti i files di log (riconfigurabile al momento del build).

Se l'immagine è stata prodotta in modalità standalone: 
- **/opt/hsqldb-2.7.4/hsqldb/database** database interno HSQL 

Se l'immagine è stata prodotta con l'opzione "-a tools":
- **/opt/govway-tools** path dove sono installati i tool a linea di comando dell'installer

si possono rendere queste location persistenti, montando dei volumi su queste directory; in tal caso i diritti delle directory sull'host devono essere compatibili con l'utente di esecuzione dell'immagine, come descritto nella sezione "Utente di esecuzione".

### Servizi attivi

Le immagini prodotte utilizzano un application server ospite, in ascolto per default sia in protocollo _**AJP**_ sulla porta **8009** sia in _**HTTP**_ su 3 porte in modo da gestire il traffico su ogni porta, con un listener dedicato:
- **8080**: Listener dedicato al traffico in erogazione (max-thread-pool default: 100)
- **8081**: Listener dedicato al traffico in fruizione (max-thread-pool default: 100)
- **8082**: Listener dedicato al traffico di gestione (max-thread-pool default: 20)

Le stesse tre categorie di traffico possono essere esposte anche in protocollo _**HTTPS**_, rispettivamente sulle porte **8443**, **8444** e **8445**. I listener HTTPS sono disattivati per default e si abilitano come descritto in [Configurazione HTTPS/TLS](#configurazione-httpstls).

E' possibile personalizzare i listener da attivare tramite variabili d'ambiente descritte nei paragrafi successivi.
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

Il contesto di accesso ai servizi dell`API gateway per le fruizioni di API:
```
 http://<indirizzo IP>:8081/govway/
```

### Script SQL di inizializzazione della Base Dati

All'avvio del container, sia in modalità standalone che con immagini orchestrate, vengono eseguite delle verifiche sul database per assicurarne la raggiungibilità ed il corretto popolamento; in caso venga riconosciuto uno o più database non inizializzati è possibile utilizzare gli scripts SQL interni per effettuare l'inizializzazione, valorizzando la variabile **'GOVWAY_POP_DB_SKIP'** al valore **false**.

Se si vuole esaminare gli script o utilizzarli manualmente, è possibile recuperarli dall'immagine in una delle directory standard **/opt/hsql**, **/opt/postgresql**, **/opt/mysql**, **/opt/mariadb**, **/opt/oracle** o **/opt/sqlserver**. Ad esempio per estrarre gli script SQL per PostgreSQL è possibile utilizzare il comando:

```shell
CONTAINER_ID=$(docker run -d -e GOVWAY_DEFAULT_ENTITY_NAME=Ente -e GOVWAY_DB_TYPE=postgresql linkitaly/govway:3.4.3 initsql);
docker wait ${CONTAINER_ID};
docker cp ${CONTAINER_ID}:/opt/postgresql .;
docker rm ${CONTAINER_ID}
```

#### Condivisione Database tra Categorie

Quando più categorie di dati di GovWay (Runtime, Tracciamento, Statistiche e Configurazione) condividono lo stesso database, gli script SQL generati possono includere tabelle duplicate, provocando errori durante l’esecuzione manuale. 

Per evitare questo problema, è possibile utilizzare la variabile **GOVWAY_DB_MAPPING**, che consente di indica quali categorie condividono il database con la categoria di default (Runtime).

**Sintassi:**
```
GOVWAY_DB_MAPPING="<lista_categorie>"
```

Dove `<lista_categorie>` è una lista separata da virgole delle categorie che condividono il database con Runtime:
- **T** = Tracciamento (GovWayTracciamento.sql)
- **S** = Statistiche (GovWayStatistiche.sql)
- **C** = Configurazione (GovWayConfigurazione.sql)

**Esempi:**

Tracciamento e Statistiche condividono il database con Runtime:
```shell
CONTAINER_ID=$(docker run -d -e GOVWAY_DEFAULT_ENTITY_NAME=Ente -e GOVWAY_DB_TYPE=postgresql -e GOVWAY_DB_MAPPING="T,S" linkitaly/govway:3.4.3 initsql);
docker wait ${CONTAINER_ID};
docker cp ${CONTAINER_ID}:/opt/postgresql .;
docker rm ${CONTAINER_ID}
```

Solo Tracciamento condivide il database con Runtime:
```shell
GOVWAY_DB_MAPPING="T"
```

Tutte le categorie condividono lo stesso database:
```shell
GOVWAY_DB_MAPPING="T,S,C"
```

**Comportamento:**
- Se **GOVWAY_DB_MAPPING** non è impostata: ogni categoria ha il proprio database (comportamento predefinito)
- Se impostata: le categorie indicate condividono il database con Runtime e gli script SQL vengono automaticamente modificati per rimuovere le tabelle duplicate


**ATTENZIONE:** quando il container viene avviato bisogna assicurarsi di aver configurato le variabili di **Connessione ai database esterni** coerentemente con quanto dichiarato nella fase di generazione degli scripts nella variabile **GOVWAY_DB_MAPPING**

### Comandi di inizializzazione aggiuntiva

La sequenza di avvio avvio del container, sia in modalità standalone che con immagini orchestrate, consente di valutare dei comandi di inizializzazione aggiuntiva, inserendoli sotto la directory **/docker-entrypoint-govway.d/**

Tutti i files trovati sotto quella directory vengono valutati in ordine alfabetico, suddivisi e gestiti come segue:
- files con estensione **'.sh'** non eseguibili:  vengono trattati come scripts di shell e viene fatto il source del contenuto (import nella shell attuale)
- files con estensione **'.sh'** eseguibili:  vengono eseguiti con l'utente di sistema **wildfly** o **tomcat**
- files con estensione **'.cli'**: vengono trattati come script di command line wildfly e vengono passati all 'interprete **${JBOSS_HOME}/bin/jboss-cli.sh** o **/usr/local/bin/tomcat-cli.sh**
- tutti gli altri files : vengono ignorati

La valutazione dei comandi di inizializzazione viene fatta dopo le verifiche e l'eventuale inizializzazione del database, ma prima dell'avvio dell'application server; inoltre la valutazione avviene solamente al primo avvio del container. 

Qualsiasi errore generato da uno qualsiasi dei comandi eseguiti viene ignorato, ed il processo di valutazione avanza al file successivo.

### Utente di esecuzione

Nessuna delle immagini prodotte viene eseguita come utente root. L'utente utilizzato a runtime dipende dal tipo di immagine:

| Immagine | Utente | uid:gid |
| --- | --- | --- |
| tomcat9 / tomcat10 | tomcat | 100:101 |
| wildfly25 / wildfly35 | wildfly | 100:101 |
| batch | govway | 100:101 |
| tools | govway | 100:101 |

Le directory di lavoro interne all'immagine appartengono all'utente indicato e al gruppo '0', con permessi di scrittura per il gruppo. Le immagini batch e tools aggiungono inoltre il gruppo '0' fra i gruppi secondari dell'utente: questo consente loro di essere eseguite con uno UID arbitrario, come avviene negli ambienti che lo assegnano automaticamente (es. le SCC di OpenShift) o nei cluster Kubernetes con Pod Security Standard 'restricted'.

Le directory montate come volumi esterni devono quindi risultare scrivibili da tale utente. La modalità più portabile consiste nell'assegnarle al gruppo '0' rendendole scrivibili dal gruppo:

```shell
chown -R 100:0 ~/govway_conf ~/govway_log
chmod -R g+rwX ~/govway_conf ~/govway_log
```

> **_NOTA:_** l'immagine batch non utilizza **/etc/govway**; l'unica directory in cui scrive è **/var/log/govway**.

## Aggiornamento di Versione

Oltre all'eventuale aggiornamento della base dati, un upgrade può richiedere di adeguare i diritti delle directory montate come volumi esterni, nei casi in cui sia cambiato l'utente di esecuzione dell'immagine.

### Upgrade dell'immagine batch da una versione precedente alla v3.4.4 / v3.3.21

L'immagine batch non viene più eseguita come utente root, allineandosi alle immagini basate su application server. Nel caso sia stato utilizzato un volume esterno per i log è necessario aggiornarne i diritti:

```shell
chown -R 100:0 ~/govway_log
chmod -R g+rwX ~/govway_log
```

L'assegnazione al gruppo '0' con permessi di scrittura per il gruppo, anziché all'id-gruppo '101' dell'utente, non è casuale: è ciò che rende l'immagine utilizzabile anche negli ambienti che assegnano al container uno UID arbitrario, non presente in `/etc/passwd`. In questi casi l'unica appartenenza garantita è quella al gruppo '0', ed è il motivo per cui l'utente 'govway' vi viene aggiunto come gruppo secondario.

Rientrano in questa casistica i cluster Kubernetes con Pod Security Standard 'restricted' (che impongono `runAsNonRoot=true`) e le Security Context Constraints di OpenShift, che assegnano a ciascun namespace un intervallo di UID proprio. In tali ambienti non è necessario indicare alcun utente nel deployment: è sufficiente che le directory montate appartengano al gruppo '0' e siano scrivibili dal gruppo.

### Upgrade di una versione precedente alla v3.3.16.b1

Cambio di utente dovuto alla modifica del sistema operativo di base da Ubuntu 22 LTS (Jammy) a Alpine; l'utente diventa 'tomcat' con id-utente '100' e id-gruppo '101':

```shell
chown -R 100:101 ~/govway_conf
chown -R 100:101 ~/govway_log
chown -R 100:101 ~/govway_db
```

### Upgrade di una versione precedente alla v3.3.15 fino alla v3.3.16

Cambio di utente dovuto alla modifica dell'application server di base da wildfly 26.1.3 a tomcat 9.0.x; va utilizzato l'id-utente '999' di tomcat:

```shell
chown -R 999:999 ~/govway_conf
chown -R 999:999 ~/govway_log
chown -R 999:999 ~/govway_db
```

## Informazioni sulle immagini batch
Utilizzando lo switch "-a" dello script di build è possibile costruire una immmagine contenente solamente il software necessario all'esecuzione dei batch di generazione statistiche.
Questo tipo di immagini si differenzia dalle immagini run, manager e full per il fatto che non viene istanziato un server che rimane in ascolto, ma viene eseguito un singolo task destinato a terminare in un tempo finito.

### Tipo di statistiche da generare ###
Il batch è in grado di gestire:
- generazione di statistiche con campionamento orario;
- generazione di statistiche con campionamento giornaliero; 
- generazione di report CSV nel formato atteso dalla PDND;
- pubblicazione dei report CSV prodotti tramite le API Interop della PDND.

Il tipo di batch da eseguire viene deciso attraverso un'argomento passato a runtime che può essere valorizzato tramite uno dei seguenti valori, in relazione ai tipi di gestione precedentemente descritti:
- orarie
- giornaliere
- generaReportPDND
- pubblicaReportPDND

I comandi forniti possono variare tra minuscole e maiuscole poichè viene verificata la corrispondenza dell'argomento rispettivamente con i pattern **"[oO]rari[ea]"** , **"[gG]iornalier[ea]"**, **"[gG]enera[Rr]eport[Pp][Dd][Nn][Dd]"** e **"[pP]ubblica[Rr]eport[Pp][Dd][Nn][Dd]"**.

Se non viene passato alcun argomento il default è orarie
Es:
```bash
docker run \
-e GOVWAY_DB_TYPE=postgresql \
-e <ALTRE_VARIABILI_DI_CONFIGURAZIONE> \
.... \
linkitaly/govway:3.4.3_batch giornaliere
```

### Modalita Cron ###
Il batch è stato creato per essere eseguito da uno schedulatore orchestrato (es Cronjobs kubernetes), quindi la schedulazione è demandata a questi sistemi. 

Se non disponibile è possibile abilitare la modalità cron. In questa modalità, il container creato schedula autonomamente l'esecuzione del batch; inoltre è possibile indicare con quali intervallo eseguire il batch.

## Personalizzazioni
Attraverso l'impostazione di alcune variabili d'ambiente note è possibile personalizzare alcuni aspetti del funzionamento dei container. Le variabili supportate al momento sono queste:

* GOVWAY_DB_TYPE: Indica il tipo di database da utilizzare (Obbligatorio, valori ammessi: hsql, postgresql, mysql, mariadb, oracle, sqlserver)
* GOVWAY_DEFAULT_ENTITY_NAME: Indica il nome del soggetto di default utilizzato (Obbligatorio)

### Controlli all'avvio del container

A runtime il container esegue i controlli di: raggiungibilita del database, di popolamento del database e di avvio di govway. Questi controlli possono essere abilitati o meno impostando le seguenti variabili d'ambiente:

* GOVWAY_LIVE_DB_CHECK_SKIP: Salta il controllo di raggiungibilità dei server database allo startup (default: FALSE)

* GOVWAY_READY_DB_CHECK_SKIP: Salta il controllo di popolamento dei database allo startup (default: FALSE)

* GOVWAY_STARTUP_CHECK_SKIP: Salta il controllo di avvio di govway allo startup (default: FALSE)

* GOVWAY_POP_DB_SKIP: Salta il popolamento automatico delle tabelle (default: TRUE)

E' possibile personalizzare il ciclo di controllo di raggiungibilità dei server database impostando le seguenti variabili d'ambiente:
* GOVWAY_LIVE_DB_CHECK_FIRST_SLEEP_TIME: tempo di attesa, in secondi, prima di effettuare la prima verifica (default: 0)
* GOVWAY_LIVE_DB_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un tentativo di connessione fallito ed il successivo (default: 2)
* GOVWAY_LIVE_DB_CHECK_MAX_RETRY: Numero massimo di tentativi di connessione (default: 30)
* GOVWAY_LIVE_DB_CHECK_CONNECT_TIMEOUT: Timeout di connessione al server, in secondi (default: 5)


E' possibile personalizzare il ciclo di controllo di popolamento dei server database impostando le seguenti variabili d'ambiente:
* GOVWAY_READY_DB_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un tentativo di connessione fallito ed il successivo (default: 2)
* GOVWAY_READY_DB_CHECK_MAX_RETRY: Numero massimo di tentativi di connessione (default: 5)


E' possibile personalizzare il ciclo di controllo di avvio di govway impostando le seguenti variabili d'ambiente:
* GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME: tempo di attesa, in secondi, prima di effettuare il primo controllo (default: 20)
* GOVWAY_STARTUP_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un controllo fallito ed il successivo  (default: 5)
* GOVWAY_STARTUP_CHECK_MAX_RETRY: Numero massimo di controlli effettuati (default: 60)

### Connessione a database esterni 

* GOVWAY_DS_JDBC_LIBS: path sul filesystem del container, ad una directory dove sono contenuti uno o più file jar necessari per l'interfacciamento al database
di cui almeno uno deve implementare l'interfaccia JDBC java.sql.Driver (obbligatorio per tutti i database tranne HSQL)

  ***AVVISO COMPORTAMENTO DEPRECATO: le immagini PostgreSQL al momento contengono un driver JDBC interno, che viene utilizzato per le connessioni JDBC. Nelle prossime versioni, il driver interno sarà eliminato e sara quindi obbligatorio fornire le librerie attraverso la variabile GOVWAY_DS_JDBC_LIBS***
  
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
Quando ci si connette ad un database esterno Oracle devono essere indicate anche le seguenti variabili d'ambiente

* GOVWAY_ORACLE_JDBC_URL_TYPE (SID/SERVICENAME): indica se connettersi ad un SID o ad un ServiceName Oracle (default: SERVICENAME)
* ~GOVWAY_ORACLE_JDBC_PATH: path sul filesystem del container, al driver jdbc da utilizzare~ **[DEPRECATA in favore di GOVWAY_DS_JDBC_LIBS]**

#### Connessione a database SQL Server ####
Quando ci si connette ad un database esterno SQL Server è possibile configurare la cifratura a livello di trasporto tramite le seguenti variabili d'ambiente:

* GOVWAY_SQLSERVER_ENCRYPT (TRUE/FALSE): abilita o disabilita la cifratura del trasporto JDBC (default: TRUE)
* GOVWAY_SQLSERVER_TRUSTSTORE: path sul filesystem del container, al file truststore Java per la verifica del certificato server (default: vuoto)
* GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD: password del truststore (default: vuoto)

**Modalità operative:**
- **Default** (nessuna variabile impostata): cifratura abilitata senza verifica del certificato server (`encrypt=true;trustServerCertificate=true`)
- **Con truststore** (`GOVWAY_SQLSERVER_TRUSTSTORE` valorizzato): cifratura abilitata con verifica del certificato server (`encrypt=true;trustServerCertificate=false;trustStore=<path>;trustStorePassword=<pass>`)
- **Disabilitata** (`GOVWAY_SQLSERVER_ENCRYPT=FALSE`): nessuna cifratura (`encrypt=false`)

### Pooling connessioni database

E' possibile personalizzare alcuni aspetti relativi ai datasource utilizzati da GovWay per accedere al database; per farlo si possono impostare i valori delle variabili d'ambiente elencate di seguito:

* GOVWAY_MAX_POOL: Numero massimo di connessioni stabilite (default: 10)
* GOVWAY_MIN_POOL: Numero minimo di connessioni stabilite (default: 2)
* GOVWAY_INITIALSIZE_POOL: Numero di connessioni stabilite ad inizializzazione del datasource (default: 2)
* GOVWAY_DS_BLOCKING_TIMEOUT: Tempo di attesa, im millisecondi, per una connessione libera dal pool (default: 30000)
* GOVWAY_DS_IDLE_TIMEOUT: Tempo trascorso, in minuti, prima di eliminare una connessione dal pool per inattivita (default: 5)
* GOVWAY_DS_CONN_PARAM: parametri JDBC aggiuntivi (default: vuoto)
* GOVWAY_DS_PSCACHESIZE: dimensione della cache usata per le prepared statements (default: 20)

Se la configurazione di GovWay prevede di suddividere i dati su più database (configurazione, tracciamento e statistiche) è possibile personalizzare i datasource in funzione dello specifico database, utilizzando le seguenti variabili.

Datasource TRACCIAMENTO
* GOVWAY_TRAC_MAX_POOL (default: 50)
* GOVWAY_TRAC_MIN_POOL (default: 2)
* GOVWAY_TRAC_INITIALSIZE_POOL (default: 2)
* GOVWAY_TRAC_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_TRAC_DS_CONN_PARAM (default: vuoto)
* GOVWAY_TRAC_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_TRAC_DS_PSCACHESIZE (default: 20)

Datasource CONFIGURAZIONE
* GOVWAY_CONF_MAX_POOL (default: 10)
* GOVWAY_CONF_MIN_POOL (default: 2)
* GOVWAY_CONF_INITIALSIZE_POOL (default: 2)
* GOVWAY_CONF_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_CONF_DS_CONN_PARAM (default: vuoto)
* GOVWAY_CONF_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_CONF_DS_PSCACHESIZE (default: 20)

Datasource STATISTICHE
* GOVWAY_STAT_MAX_POOL (default: 5)
* GOVWAY_STAT_MIN_POOL (default: 1)
* GOVWAY_STAT_INITIALSIZE_POOL (default: 1)
* GOVWAY_STAT_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_STAT_DS_CONN_PARAM (default: vuoto)
* GOVWAY_STAT_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_STAT_DS_PSCACHESIZE (default: 20)


### Configurazione Listener 
Per configurare con quali protocolli i listener dell'application server accetteranno le richieste, è possibile utilizzare le seguenti variabili (valide per tutte le immagini, sia Tomcat che WildFly):

* GOVWAY_AS_AJP_LISTENER: Abilita o disabilita i listener AJP  (default: ajp-8009, un solo listener sulla porta 8009 - vedi [Configurazione AJP](#configurazione-ajp), valori ammissibili [true, false, ajp-8009] )
* GOVWAY_AS_HTTP_LISTENER: Abilita o disabilita i listener HTTP (default: true, valori ammissibili [true, false, http-8080] )
* GOVWAY_AS_HTTPS_LISTENER: Abilita o disabilita i listener HTTPS sulle porte 8443/8444/8445 (default: false, abilitati automaticamente se viene fornito un certificato del server - vedi [Configurazione HTTPS/TLS](#configurazione-httpstls), valori ammissibili [true, false, https-8443] )

A seconda del protocollo che si vuole configurare, valorizzando la relativa variabile a **true** si abiliteranno tutti e tre listener previsti di erogazione, fruizione e gestione. Viceversa valorizzando a **false** i tre listener verranno disabilitati.
Utilizzando i valori speciali **http-8080**, **ajp-8009** o **https-8443** verrà abilitato un solo listener per il protocollo scelto, sulla rispettiva porta di default.

Il punto di partenza è diverso a seconda del protocollo: in HTTP sono già attivi tutti e tre i listener (8080, 8081 e 8082), in AJP il solo listener di erogazione (8009), in HTTPS nessuno. Le specificità dei due protocolli non attivi per default sono descritte in [Configurazione AJP](#configurazione-ajp) e [Configurazione HTTPS/TLS](#configurazione-httpstls).

I listener possono essere ulteriormente configurati tramite le seguenti variabili:

* GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in erogazione, (default: 100) 
* GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in fruizione, (default: 100) 
* GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico di gestione, (default: 20)

* GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico in erogazione, l'unico attivo nella configurazione di default, (default: 50)
* GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico in fruizione, utilizzata solo con GOVWAY_AS_AJP_LISTENER=true, (default: 100)
* GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico di gestione, utilizzata solo con GOVWAY_AS_AJP_LISTENER=true, (default: 20)


* GOVWAY_AS_HTTPS_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTPS per il traffico in erogazione, (default: 100)
* GOVWAY_AS_HTTPS_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTPS per il traffico in fruizione, (default: 100)
* GOVWAY_AS_HTTPS_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTPS per il traffico di gestione, (default: 20)

* GOVWAY_AS_MAX_POST_SIZE: Dimensione massima consentita per il body dei messaggi. Si applica a tutti i listener abilitati (default: 10485760 bytes)
* GOVWAY_AS_MAX_HTTP_SIZE: Dimensione massima cumulata di tutti gli header http inviati. Si applica a tutti i listener abilitati (default: 1048576 bytes sulle immagini Tomcat, 10485760 bytes sulle immagini WildFly)

#### Avviso variabili deprecate
Di seguito una lista di variabili usate in precedenza per la configurazione dei Listener. Queste variabili sono state deprecate e verrano rimosse nelle versioni successive:

* ~WILDFLY_AJP_LISTENER: Abilita o disabilita i listener AJP  (default: ajp-8009, valori ammissibili [true, false, ajp-8009] )~ **[DEPRECATA in favore di GOVWAY_AS_AJP_LISTENER]**
* ~WILDFLY_HTTP_LISTENER: Abilita o disabilita i listener HTTP (default: true, valori ammissibili [true, false, http-8080] )~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_LISTENER]**

* ~WILDFLY_HTTP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in erogazione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS]**
* ~WILDFLY_HTTP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in fruizione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS]**
* ~WILDFLY_HTTP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico di gestione, (default: 20)~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS]**

* ~WILDFLY_AJP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico in erogazione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS]**
* ~WILDFLY_AJP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il  traffico in fruizione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS]**
* ~WILDFLY_AJP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico di gestione, (default: 20)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS]**
* ~GOVWAY_AS_AJP_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico in erogazione, (default: 50)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS]**

* ~WILDFLY_MAX_POST_SIZE: Dimensione massima consentita per i messaggi. Si applica a tutti i listener abilitati (default: 10485760 bytes)~ **[DEPRECATA in favore di GOVWAY_AS_MAX_POST_SIZE]**

#### Configurazione AJP

Nella configurazione di default è attivo un unico listener AJP, sulla porta **8009**, dedicato al traffico in erogazione. Con `GOVWAY_AS_AJP_LISTENER=true` si aggiungono il listener di fruizione, sulla porta **8010**, e quello di gestione, sulla porta **8011**: queste due porte non sono esposte dall'immagine, quindi per raggiungerle vanno pubblicate esplicitamente all'avvio del container.

##### Segreto condiviso e indirizzo di ascolto

Il protocollo AJP presuppone che a dialogare con l'application server sia unicamente un reverse proxy fidato (mod_jk, mod_proxy_ajp) sulla stessa rete: chi apre una connessione AJP può impostare direttamente gli attributi interni della richiesta. Per questo motivo, dopo la vulnerabilità nota come Ghostcat (CVE-2020-1938), Tomcat per default fa ascoltare i connettori AJP solo sull'indirizzo di loopback e richiede la configurazione di un segreto condiviso. Le immagini mantengono questo comportamento; le variabili seguenti permettono di aprire l'ascolto e di configurare il segreto quando i connettori AJP devono essere raggiunti da un proxy esterno al container.

Sono supportate **solo dalle immagini Tomcat**: il listener AJP di WildFly non prevede alcun segreto condiviso e il suo indirizzo di ascolto è quello dell'interfaccia public dell'application server. Se valorizzate su un'immagine WildFly vengono ignorate, segnalandolo nei log.

* GOVWAY_AS_AJP_ADDRESS: Indirizzo su cui i connettori AJP accettano le connessioni. Col valore di default i connettori sono raggiungibili solo dall'interno del container: per utilizzare l'AJP da un proxy esterno indicare 0.0.0.0 (default: 127.0.0.1)
* GOVWAY_AS_AJP_SECRET_VALUE: Segreto condiviso richiesto ai client AJP, da configurare con lo stesso valore anche sul proxy (worker.X.secret in mod_jk, secret= in mod_proxy_ajp). Valorizzarla attiva automaticamente la richiesta del segreto su tutti i connettori AJP abilitati (default: vuoto)
* GOVWAY_AS_AJP_SECRET_VALUE_FILE: Path ad un file contenente il segreto condiviso, alternativa prioritaria a GOVWAY_AS_AJP_SECRET_VALUE (default: vuoto)
* GOVWAY_AS_AJP_SECRET: Richiede il segreto condiviso sui connettori AJP (attributo secretRequired di Tomcat). Non è necessario impostarla se si valorizza il segreto, che la attiva implicitamente; valorizzata a true senza indicare il segreto interrompe l'avvio con un errore esplicito (default: false)

Come per le altre modifiche ai connettori, la configurazione viene applicata una sola volta per container: cambiare il segreto o l'indirizzo di ascolto richiede di ricreare il container.

#### Configurazione HTTPS/TLS

Oltre alle porte HTTP (8080/8081/8082) è possibile esporre le stesse tre categorie di traffico (erogazione, fruizione e gestione) anche in HTTPS, rispettivamente sulle porte **8443**, **8444** e **8445**. Le porte HTTP restano attive: i listener HTTPS si affiancano, non le sostituiscono.

Senza alcuna variabile `GOVWAY_AS_HTTPS_*` impostata il comportamento è identico alle versioni precedenti: nessuna modifica alla configurazione dell'application server e nessuna porta HTTPS in ascolto. I listener HTTPS si attivano:

- **esplicitamente**, con `GOVWAY_AS_HTTPS_LISTENER=true` (oppure `https-8443` per abilitare solo il listener di erogazione);
- **implicitamente**, non appena viene valorizzata una delle variabili che indicano il certificato del server, ossia `GOVWAY_AS_HTTPS_CERTIFICATE` o `GOVWAY_AS_HTTPS_KEYSTORE` (anche nella forma con suffisso per singolo listener). Le variabili che riguardano la sola client authentication, `GOVWAY_AS_HTTPS_TRUSTSTORE` e `GOVWAY_AS_HTTPS_CA_CERTIFICATE`, non sono sufficienti ad attivare i listener.

Il certificato del server può essere fornito in tre modalità alternative, alle quali si aggiunge la client authentication, combinabile con ognuna delle tre:

* **(a) certificato self-signed**: nessuna variabile di certificato impostata; il container ne genera uno all'avvio, segnalandolo con un WARN esplicito. Da utilizzare esclusivamente per test.
* **(b) certificato PEM montato**: certificato, chiave privata ed eventuale catena forniti come file PEM.
* **(c) keystore montato**: certificato e chiave forniti all'interno di un keystore PKCS12 o JKS.
* **(d) client authentication (mTLS)**: verifica del certificato presentato dal client, con le CA da riconoscere fornite come bundle PEM oppure come truststore.

Le modalità (b) e (c) sono mutuamente esclusive: impostando entrambe le variabili il container si arresta all'avvio con un errore esplicito.

Il dimensionamento dei thread pool dei tre listener HTTPS si effettua con le variabili `GOVWAY_AS_HTTPS_IN_WORKER_MAX_THREADS`, `GOVWAY_AS_HTTPS_OUT_WORKER_MAX_THREADS` e `GOVWAY_AS_HTTPS_GEST_WORKER_MAX_THREADS`, documentate insieme agli altri worker nel paragrafo [Configurazione Listener](#configurazione-listener).

##### Attivazione e porte

| Variabile | Default | Descrizione |
|---|---|---|
| `GOVWAY_AS_HTTPS_LISTENER` | false | Abilita o disabilita i listener HTTPS (valori ammissibili [true, false, https-8443]). Se non impostata, i listener vengono abilitati automaticamente quando viene fornito un certificato del server |
| `GOVWAY_AS_HTTPS_PORT_EROGAZIONI` | 8443 | Porta del listener HTTPS dedicato al traffico in erogazione |
| `GOVWAY_AS_HTTPS_PORT_FRUIZIONI` | 8444 | Porta del listener HTTPS dedicato al traffico in fruizione |
| `GOVWAY_AS_HTTPS_PORT_GESTIONE` | 8445 | Porta del listener HTTPS dedicato al traffico di gestione |

Le porte indicate non possono coincidere con quelle dei listener HTTP e AJP (8080, 8081, 8082, 8009), né tra di loro: in caso di collisione il container si arresta all'avvio con un errore esplicito.

##### (a) Certificato self-signed

Variabili utilizzate soltanto quando i listener HTTPS sono attivi e non è stato indicato alcun certificato.

| Variabile | Default | Descrizione |
|---|---|---|
| `GOVWAY_AS_HTTPS_SELF_SIGNED_CN` | `localhost` | Common Name del certificato generato |
| `GOVWAY_AS_HTTPS_SELF_SIGNED_SAN` | `DNS:localhost,DNS:<hostname>,IP:127.0.0.1` | Subject Alternative Name del certificato generato, nella sintassi dell'opzione `subjectAltName` di openssl |
| `GOVWAY_AS_HTTPS_SELF_SIGNED_VALIDITY` | 825 | Giorni di validità del certificato generato |

##### (b) Certificato PEM montato

| Variabile | Default | Descrizione |
|---|---|---|
| `GOVWAY_AS_HTTPS_CERTIFICATE` | vuoto | Path al file PEM contenente il certificato del server. Valorizzarla attiva i listener HTTPS e seleziona questa modalità |
| `GOVWAY_AS_HTTPS_CERTIFICATE_KEY` | valore di `GOVWAY_AS_HTTPS_CERTIFICATE` | Path al file PEM contenente la chiave privata; se omessa si assume che chiave e certificato siano contenuti nello stesso file |
| `GOVWAY_AS_HTTPS_CERTIFICATE_CHAIN` | vuoto | Path al file PEM contenente la catena dei certificati intermedi |
| `GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD` | vuoto | Password della chiave privata, necessaria solo se la chiave è cifrata |
| `GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD_FILE` | vuoto | Path ad un file contenente la password della chiave privata, alternativa prioritaria alla variabile precedente |

##### (c) Keystore montato

| Variabile | Default | Descrizione |
|---|---|---|
| `GOVWAY_AS_HTTPS_KEYSTORE` | vuoto | Path al keystore contenente il certificato e la chiave del server. Valorizzarla attiva i listener HTTPS e seleziona questa modalità |
| `GOVWAY_AS_HTTPS_KEYSTORE_TYPE` | dedotto dall'estensione del file: JKS per `.jks` e `.keystore`, PKCS12 negli altri casi | Tipo di keystore |
| `GOVWAY_AS_HTTPS_KEYSTORE_ALIAS` | vuoto | Alias della entry da utilizzare, per keystore che contengono più certificati |
| `GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD` | vuoto | Password del keystore; obbligatoria, in questa forma o in quella `_FILE`, quando è impostata `GOVWAY_AS_HTTPS_KEYSTORE` |
| `GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD_FILE` | vuoto | Path ad un file contenente la password del keystore, alternativa prioritaria alla variabile precedente |
| `GOVWAY_AS_HTTPS_KEY_PASSWORD` | password del keystore | Password della chiave privata, necessaria solo se la entry indicata ha una password diversa da quella del keystore |
| `GOVWAY_AS_HTTPS_KEY_PASSWORD_FILE` | vuoto | Path ad un file contenente la password della chiave privata, alternativa prioritaria alla variabile precedente |

##### (d) Client authentication (mTLS)

| Variabile | Default | Descrizione |
|---|---|---|
| `GOVWAY_AS_HTTPS_CLIENT_AUTH` | none | Modalità di verifica del certificato presentato dal client (valori ammissibili [none, optional, required]). Un valore diverso da none richiede `GOVWAY_AS_HTTPS_CA_CERTIFICATE` oppure `GOVWAY_AS_HTTPS_TRUSTSTORE` |
| `GOVWAY_AS_HTTPS_CA_CERTIFICATE` | vuoto | Path ad un bundle PEM contenente una o più CA da riconoscere; viene convertito automaticamente in un truststore interno al container. È la modalità consigliata |
| `GOVWAY_AS_HTTPS_TRUSTSTORE` | vuoto | Path ad un truststore già predisposto, in alternativa al bundle PEM |
| `GOVWAY_AS_HTTPS_TRUSTSTORE_TYPE` | dedotto dall'estensione del file: JKS per `.jks` e `.keystore`, PKCS12 negli altri casi | Tipo di truststore |
| `GOVWAY_AS_HTTPS_TRUSTSTORE_PASSWORD` | `govway` | Password del truststore indicato con `GOVWAY_AS_HTTPS_TRUSTSTORE` |
| `GOVWAY_AS_HTTPS_TRUSTSTORE_PASSWORD_FILE` | vuoto | Path ad un file contenente la password del truststore, alternativa prioritaria alla variabile precedente |

Tipicamente la client authentication va richiesta sul traffico in erogazione e fruizione, lasciando il valore none sul listener di gestione: diversamente le console web non risultano più raggiungibili da browser. Si ottiene con l'override per singolo listener descritto di seguito.

##### Parametri del protocollo TLS

| Variabile | Default | Descrizione |
|---|---|---|
| `GOVWAY_AS_HTTPS_PROTOCOLS` | `TLSv1.2,TLSv1.3` | Elenco, separato da virgole, dei protocolli TLS accettati dai listener |
| `GOVWAY_AS_HTTPS_CIPHERS` | default dell'application server | Elenco dei cifrari accettati dai listener. La sintassi del valore non è portabile tra Tomcat e WildFly |
| `GOVWAY_AS_HTTPS_HTTP2` | false | Abilita HTTP/2 sui listener HTTPS |
| `GOVWAY_AS_HTTPS_PROXY_FORWARDING` | false | Solo per le immagini Tomcat: allinea la porta riportata dall'application server alla prima porta HTTPS attiva, negli scenari in cui GovWay è posto dietro un reverse proxy che termina il TLS |

##### Override per singolo listener

Tutte le variabili elencate nei paragrafi precedenti, con l'eccezione di `GOVWAY_AS_HTTPS_LISTENER` e `GOVWAY_AS_HTTPS_PROXY_FORWARDING` che valgono sempre globalmente, accettano i suffissi `_EROGAZIONI`, `_FRUIZIONI` e `_GESTIONE`: la variabile senza suffisso vale per tutti e tre i listener, quella con suffisso ne effettua l'override sul singolo listener. Ad esempio `GOVWAY_AS_HTTPS_CLIENT_AUTH=required` insieme a `GOVWAY_AS_HTTPS_CLIENT_AUTH_GESTIONE=none` richiede il certificato client solo sul traffico in erogazione e fruizione.

La variabile `GOVWAY_AS_HTTPS_PORT` senza suffisso assegnerebbe la stessa porta a tutti i listener attivi: va quindi utilizzata solo con `GOVWAY_AS_HTTPS_LISTENER=https-8443`, valorizzando negli altri casi le tre varianti con suffisso.

##### Password su file

Ognuna delle quattro password (`GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD`, `GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD`, `GOVWAY_AS_HTTPS_KEY_PASSWORD`, `GOVWAY_AS_HTTPS_TRUSTSTORE_PASSWORD`) dispone di una variante con suffisso **_FILE**, che indica il path di un file contenente la password anziché la password stessa: è la forma da preferire negli ambienti orchestrati, dove il valore viene fornito come secret montato nel container. Se sono impostate entrambe le forme viene segnalato un WARN e prevale quella `_FILE`; se il file indicato non è leggibile dall'utente del container, l'avvio si interrompe con un errore esplicito.

Le varianti `_FILE` vanno indicate in forma globale, valida per tutti i listener: il nome da utilizzare per l'override su un singolo listener non è attualmente uniforme tra le immagini Tomcat e WildFly.

##### Esempi

```bash
# (a) Solo attivazione, certificato self-signed generato automaticamente
docker run ... -e GOVWAY_AS_HTTPS_LISTENER=true ...

# (b) Certificato PEM montato
docker run ... -v /path/certs:/certs:ro \
  -e GOVWAY_AS_HTTPS_CERTIFICATE=/certs/fullchain.pem \
  -e GOVWAY_AS_HTTPS_CERTIFICATE_KEY=/certs/privkey.pem ...

# (c) Keystore PKCS12 montato
docker run ... -v /path/keystore.p12:/certs/keystore.p12:ro \
  -e GOVWAY_AS_HTTPS_KEYSTORE=/certs/keystore.p12 \
  -e GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD_FILE=/run/secrets/keystore_password ...

# (d) mTLS su erogazione/fruizione, console di gestione raggiungibile senza certificato client
docker run ... \
  -e GOVWAY_AS_HTTPS_CLIENT_AUTH=required \
  -e GOVWAY_AS_HTTPS_CLIENT_AUTH_GESTIONE=none \
  -e GOVWAY_AS_HTTPS_CA_CERTIFICATE=/certs/ca-bundle.pem ...
```

##### Limiti noti

- Su Tomcat, la verifica della catena CA (`GOVWAY_AS_HTTPS_CA_CERTIFICATE`) usa JSSE (non è disponibile `tomcat-native`/OpenSSL): un bundle PEM viene sempre convertito internamente in un truststore.
- Il modo PEM (b) richiede una conversione a PKCS12 su WildFly (Elytron non ha un tipo key-store PEM); su Tomcat invece il PEM è supportato nativamente, nessuna conversione.
- La riconfigurazione non è "a caldo": cambiare porte o materiale crittografico richiede di ricreare il container (i marker di inizializzazione rendono l'operazione one-shot per container, come per i datasource).
- SNI e certificati diversi per host virtuale sullo stesso connettore non sono supportati.

### Configurazioni avanzate
* GOVWAY_SUSPEND_TIMEOUT: Tempo massimo di attesa per la chiusura delle richiesta attive in fase di spegnimento dell'application server. (default: 20s)
* GOVWAY_JVM_AGENT_JAR: Path ad un jar agent da caricare all'avvio dell'application server (Ex OpenTelemetry)
* GOVWAY_UUID_ALG: Algoritmo utilizzato internamente per la generazione degli UUID. (default: v1, valori ammissibili [v1, v4, {ID Algoritmo}] )

  La lista degli algoritmi utilizzabili si puo recuperare dal file __govway.classRegistry.properties__  dalle proprietà del tipo **org.openspcoop2.id.{ID Algoritmo}**. Inoltre si possono utilizzare le seguenti abbreviazioni:
  - v1 o V1 ->  UUIDv1
  - v4 o V4 ->  UUIDv4sec

#### Proprietà JVM Personalizzate

È possibile iniettare proprietà JVM personalizzate nel container montando un file di configurazione esterno.

**Path supportati:**
* `/etc/govway_as_jvm.properties` (raccomandato)
* `/etc/wildfly/wildfly.properties` (deprecato, mantenuto per retrocompatibilità)

**Funzionamento:**
All'avvio del container, se esiste uno dei file sopra indicati, il suo contenuto viene automaticamente iniettato nelle proprietà di sistema della JVM:
- **Tomcat**: il contenuto viene aggiunto a `${CATALINA_HOME}/conf/catalina.properties`
- **WildFly**: le proprietà vengono configurate tramite system-properties della JVM

**Esempio di utilizzo:**

Creare un file `custom.properties`:
```properties
org.govway.custom.property=valore
my.application.setting=123
```

Montare il file nel container tramite docker-compose:
```yaml
services:
  govway:
    image: linkitaly/govway:3.4.3
    environment:
      - GOVWAY_DB_TYPE=postgresql
    volumes:
      - ./custom.properties:/etc/govway_as_jvm.properties:ro
```

O tramite docker run:
```bash
docker run -e GOVWAY_DB_TYPE=postgresql -v ./custom.properties:/etc/govway_as_jvm.properties:ro linkitaly/govway:3.4.3
```

Le proprietà definite nel file diventano accessibili come system properties all'interno dell'applicazione GovWay.

#### Configurazione Memoria JVM

Le seguenti variabili permettono di configurare l'utilizzo della memoria da parte della JVM.
Le impostazioni utilizzano RAM Percentage per adattarsi automaticamente ai limiti di memoria del container.

**Heap Memory (RAM Percentage):**
* GOVWAY_JVM_INITIAL_RAM_PERCENTAGE: Percentuale di RAM allocata all'heap all'avvio della JVM tramite property -XXInitialRAMPercentage (default: non impostato, utilizza il default della JVM)
* GOVWAY_JVM_MIN_RAM_PERCENTAGE: Percentuale minima di RAM riservata all'heap tramite property -XX:MinRAMPercentage (default: non impostato, utilizza il default della JVM)
* GOVWAY_JVM_MAX_RAM_PERCENTAGE: Percentuale massima di RAM del container utilizzabile per l'heap JVM tramite property -XX:MaxRAMPercentage (default: 50 per immagini manager/all, 80 per immagini runtime e batch)

**Metaspace e Direct Memory:**
* GOVWAY_JVM_MAX_METASPACE_SIZE: Dimensione massima del metaspace per il caricamento delle classi tramite property -XX:MaxMetaspaceSize (es: "256m", "512m", default: illimitato)
* GOVWAY_JVM_MAX_DIRECT_MEMORY_SIZE: Dimensione massima dei buffer di memoria diretta usati per operazioni I/O tramite property -XX:MaxDirectMemorySize (es: "512m", "1g", default: uguale a MaxHeapSize)

**Nota:** Le impostazioni basate su percentuale si adattano automaticamente quando il container viene ridimensionato o spostato su nodi con limiti di memoria diversi, rendendole ideali per ambienti Kubernetes e altri orchestratori.

**Esempio:**
```yaml
environment:
  - GOVWAY_JVM_MAX_RAM_PERCENTAGE=70
  - GOVWAY_JVM_INITIAL_RAM_PERCENTAGE=50
  - GOVWAY_JVM_MAX_METASPACE_SIZE=256m
```

#### Proprietà JVM aggiuntive (keystore e truststore di rete)

La variabile **JAVA_OPTS** consente di passare alla JVM proprietà arbitrarie: il suo contenuto viene preservato dall'entrypoint, che vi accoda le opzioni di memoria descritte sopra. È la modalità con cui si configurano il keystore ed il truststore utilizzati dalla JVM per le connessioni TLS in uscita, ad esempio verso la PDND, un Identity Provider o un servizio erogato in HTTPS.

**NOTA:** queste proprietà riguardano le connessioni che GovWay apre verso l'esterno. Per abilitare il TLS sulle porte in ascolto (erogazione, fruizione, gestione) si utilizzano invece le variabili descritte nella sezione "Configurazione Listener".

* javax.net.ssl.trustStore: path del truststore utilizzato per validare i certificati dei server contattati
* javax.net.ssl.trustStoreType: tipo di truststore (es. JKS, PKCS12)
* javax.net.ssl.trustStorePassword: password del truststore
* javax.net.ssl.keyStore: path del keystore contenente il certificato client, per le connessioni in mutua autenticazione
* javax.net.ssl.keyStoreType: tipo di keystore (es. JKS, PKCS12)
* javax.net.ssl.keyStorePassword: password del keystore

**Esempio:**
```yaml
volumes:
  - ~/govway_keys:/etc/govway/keys:ro
environment:
  - JAVA_OPTS=-Djavax.net.ssl.trustStore=/etc/govway/keys/truststore.p12 -Djavax.net.ssl.trustStoreType=PKCS12 -Djavax.net.ssl.trustStorePassword=secret -Djavax.net.ssl.keyStore=/etc/govway/keys/keystore.p12 -Djavax.net.ssl.keyStoreType=PKCS12 -Djavax.net.ssl.keyStorePassword=secret
```

I file di keystore e truststore non sono presenti nell'immagine e devono essere resi disponibili al container montando un volume, come nell'esempio; il path indicato nelle proprietà è quello interno al container.

**NOTA:** impostando un truststore si sostituisce quello di default della JVM, che contiene le Certification Authority pubbliche: i certificati di queste ultime, se ancora necessari, vanno importati nel truststore fornito.

**NOTA:** le password indicate in JAVA_OPTS compaiono nella riga di comando del processo java. In alternativa alle proprietà di sistema, GovWay consente di configurare keystore e truststore sui singoli connettori, dove le password sono gestite tramite il vault.

#### Avviso variabili deprecate
Di seguito una lista di variabili usate in precedenza per la configurazione avanzata. Queste variabili sono state deprecate e verrano rimosse nelle versioni successive:

* ~WILDFLY_SUSPEND_TIMEOUT~: Tempo massimo di attesa per la chiusura delle richiesta attive in fase di spegnimento di wildfly. Non ha effetti per le immagini che usano Tomcat. (default: 20s) **[DEPRECATA in favore di GOVWAY_SUSPEND_TIMEOUT]**
* ~MAX_JVM_PERC~: Percentuale massima di RAM utilizzabile dalla JVM (default: 80) **[DEPRECATA in favore di GOVWAY_JVM_MAX_RAM_PERCENTAGE]**

## Personalizzazioni Batch

### Modalita Cron

* GOVWAY_BATCH_USA_CRON: indica se abilitare la modalità cron (default: no , valori ammissibili [si, yes, 1, true])
* GOVWAY_BATCH_INTERVALLO_CRON: indica l'intervallo di schedulazione del batch in minuti (default: 5 per statistiche orarie | 30 per statisiche giornaliere, generazione e pubblicazione di report PDND) 


### Connessione a database esterni

Il batch richiede l'accesso alle tabelle che memorizzano i dati delle seguenti categorie CONFIGURAZIONE, TRACCIAMENTO e STATISTICHE.
Per default si suppone che queste siano presenti sullo stesso database indicato dalle seguenti variabili obbligatorie:

* GOVWAY_DB_TYPE: Indica il tipo di database da utilizzare (Obbligatorio, valori ammessi: postgresql, mysql, mariadb, oracle, sqlserver)

  **NOTA:** Il batch non supporta il database HSQL in quanto richiede un database esterno per l'accesso concorrente ai dati.

* GOVWAY_DS_JDBC_LIBS: path sul filesystem del container, ad una directory dove sono contenuti uno o più file jar necessari per l'interfacciamento al database
di cui almeno uno deve implementare l'interfaccia JDBC java.sql.Driver

  ***AVVISO COMPORTAMENTO DEPRECATO: le immagini PostgreSQL al momento contengono un driver JDBC interno, che viene utilizzato per le connessioni JDBC. Nelle prossime versioni, il driver interno sarà eliminato e sara quindi obbligatorio fornire le librerie attraverso la variabile GOVWAY_DS_JDBC_LIBS***

* GOVWAY_STAT_DB_SERVER: nome dns o ip address del server database (obbligatorio)
* GOVWAY_STAT_DB_NAME: Nome del database delle statistiche (obbligatorio)
* GOVWAY_STAT_DB_USER: username da utilizzare per l'accesso al database (obbligatorio)
* GOVWAY_STAT_DB_PASSWORD: password di accesso al database (obbligatorio)
  
Se la configurazione lo richiede è possibile
indicare puntamenti differenti per le tabelle delle restanti categorie, usando i seguenti set di variabili

CONFIGURAZIONE
* GOVWAY_CONF_DB_SERVER (default: GOVWAY_STAT_DB_SERVER)
* GOVWAY_CONF_DB_NAME (default: GOVWAY_STAT_DB_NAME)
* GOVWAY_CONF_DB_USER (default: GOVWAY_STAT_DB_USER)
* GOVWAY_CONF_DB_PASSWORD (default: GOVWAY_STAT_DB_PASSWORD)

TRACCIAMENTO
* GOVWAY_TRAC_DB_SERVER (default: GOVWAY_STAT_DB_SERVER)
* GOVWAY_TRAC_DB_NAME (default: GOVWAY_STAT_DB_NAME)
* GOVWAY_TRAC_DB_USER (default: GOVWAY_STAT_DB_USER)
* GOVWAY_TRAC_DB_PASSWORD (default: GOVWAY_STAT_DB_PASSWORD)

#### Connessione a database Oracle ####
Quando ci si connette ad un database esterno Oracle devono essere indicate anche le seguenti variabili d'ambiente

* GOVWAY_ORACLE_JDBC_URL_TYPE (SID/SERVICENAME): indica se connettersi ad un SID o ad un ServiceName Oracle (default: SERVICENAME)
* ~GOVWAY_ORACLE_JDBC_PATH: path sul filesystem del container, al driver jdbc da utilizzare~ **[DEPRECATA in favore di GOVWAY_DS_JDBC_LIBS]**

#### Connessione a database SQL Server ####
Quando ci si connette ad un database esterno SQL Server è possibile configurare la cifratura a livello di trasporto tramite le seguenti variabili d'ambiente:

* GOVWAY_SQLSERVER_ENCRYPT (TRUE/FALSE): abilita o disabilita la cifratura del trasporto JDBC (default: TRUE)
* GOVWAY_SQLSERVER_TRUSTSTORE: path sul filesystem del container, al file truststore Java per la verifica del certificato server (default: vuoto)
* GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD: password del truststore (default: vuoto)

**Modalità operative:**
- **Default** (nessuna variabile impostata): cifratura abilitata senza verifica del certificato server (`encrypt=true;trustServerCertificate=true`)
- **Con truststore** (`GOVWAY_SQLSERVER_TRUSTSTORE` valorizzato): cifratura abilitata con verifica del certificato server (`encrypt=true;trustServerCertificate=false;trustStore=<path>;trustStorePassword=<pass>`)
- **Disabilitata** (`GOVWAY_SQLSERVER_ENCRYPT=FALSE`): nessuna cifratura (`encrypt=false`)


### Configurazioni avanzate
* GOVWAY_JVM_AGENT_JAR: Path ad un jar agent da caricare all'avvio dell'applicazione (Ex. OpenTelemetry)

## Informazioni sull'immagine tools

Utilizzando lo switch "-a tools" dello script di build si ottiene l'immagine `linkitaly/govway:<versione>_tools`, che espone i tool a linea di comando prodotti dall'installer GovWay:

* **govway-config-loader**: caricamento di un export della console tramite azioni `create`, `createOrUpdate`, `delete`
* **govway-template-scan**: verifica dei template presenti nella configurazione
* **govway-vault-cli**: cifratura/decifratura/aggiornamento delle password gestite dal vault di GovWay, tramite azioni `encrypt`, `decrypt`, `update`

Come le immagini batch, non viene istanziato alcun application server: il container esegue un singolo tool e termina, adatto sia ad un `docker run` singolo che ad un Pod/Job Kubernetes ad esecuzione unica. Per lo stesso motivo il tag non riporta l'indicazione dell'application server, ed il parametro "-g" incide solamente sulla versione della JRE utilizzata.

```bash
./build_image.sh -a tools -v 3.4.3
```

L'immagine espone un unico entrypoint che fa da dispatcher sul tool e sull'azione richiesti:

```bash
docker run --rm \
  -e GOVWAY_DB_TYPE=postgresql \
  -e GOVWAY_DB_SERVER=pg-server -e GOVWAY_DB_NAME=govwaydb \
  -e GOVWAY_DB_USER=govway -e GOVWAY_DB_PASSWORD=govway \
  -e GOVWAY_DS_JDBC_LIBS=/tmp \
  -v ./postgresql-42.7.13.jar:/tmp/postgresql-42.7.13.jar \
  -v ./archivio.zip:/tmp/archivio.zip \
  -v ./govway_log:/var/log/govway \
  linkitaly/govway:3.4.3_tools config-loader create /tmp/archivio.zip
```

```bash
docker run --rm \
  -e GOVWAY_DB_TYPE=postgresql \
  -e GOVWAY_DB_SERVER=pg-server -e GOVWAY_DB_NAME=govwaydb \
  -e GOVWAY_DB_USER=govway -e GOVWAY_DB_PASSWORD=govway \
  -e GOVWAY_DS_JDBC_LIBS=/tmp \
  -v ./postgresql-42.7.13.jar:/tmp/postgresql-42.7.13.jar \
  -v ./govway_log:/var/log/govway \
  linkitaly/govway:3.4.3_tools template-scan '.*'
```

```bash
docker run --rm \
  -v ./byok.properties:/etc/govway/byok.properties \
  -v ./govway_log:/var/log/govway \
  linkitaly/govway:3.4.3_tools vault-cli encrypt -system_in=miosegreto -system_out
```

> **_IMPORTANTE:_** tutte le azioni di `vault-cli` (`encrypt`, `decrypt` e `update`) richiedono che siano definiti i security engine BYOK. Il file `byok.properties` **non è incluso nell'immagine** e va fornito montandolo su `/etc/govway/byok.properties`, path a cui la configurazione del tool punta già di default. In sua assenza il comando termina con l'errore `Security policy default undefined (BYOK Disabled?)`. L'esempio sopra vale per `encrypt` e `decrypt`, che non accedono al database; l'azione `update` opera invece sulle informazioni confidenziali già presenti nella base dati e richiede quindi anche le variabili di connessione descritte nella sezione "Personalizzazioni Tools". Per la sintassi dei comandi e la configurazione dei security engine si rimanda alla [documentazione del Vault CLI](https://govway.org/documentazione/installazione/finalizzazione/byok/vaultCli/index.html).

> **_IMPORTANTE:_** montare sempre `/var/log/govway` su un volume. I tool riportano nei file di log l'esito dettagliato dell'operazione, che sullo standard output non compare; inoltre terminano con exit code 0 anche quando uno o più elementi dell'archivio non vengono importati, quindi il solo exit code non è sufficiente a stabilire se l'operazione sia andata a buon fine. Con un container effimero (`docker run --rm`, Pod/Job Kubernetes) senza questo volume l'unica diagnostica disponibile viene persa insieme al container.

I comandi supportati sono:
* `config-loader create <archivePath>`
* `config-loader createOrUpdate <archivePath>`
* `config-loader delete <archivePath>`
* `template-scan <regex>`
* `vault-cli encrypt [args...]`
* `vault-cli decrypt [args...]`
* `vault-cli update [args...]`

I file di configurazione dei tre tool sono centralizzati in un'unica directory `/etc/govway`. I tool vi cercano già di default anche i file che l'immagine non include, e che vanno quindi forniti se servono: `byok.properties`, `hsm.properties`, `govway.map.properties` e `govway.secrets.properties`.

Per aggiungere o personalizzare uno di questi file conviene montare il **singolo file**, come negli esempi sopra: montando un volume sull'intera directory `/etc/govway` si nascondono tutte le properties di default presenti nell'immagine, che andrebbero a quel punto fornite per intero.

> **_NOTA:_** i file presenti in `/etc/govway` non vengono mai modificati: la directory può quindi essere montata **in sola lettura**. L'unica directory in cui l'immagine scrive è `/var/log/govway`.

I log sono centralizzati in `/var/log/govway`, come per l'immagine principale. Ogni tool scrive un proprio gruppo di file: `govway_cli_configLoader.log` (con `_sql` e `_auditing`), `govway_cli_templateScan.log` (con `_sql`) e `govway_cli_vault.log` (con `_output`).

## Personalizzazioni Tools

### Connessione a database esterni

I tool `config-loader`, `template-scan` e `vault-cli update` richiedono l'accesso al database di CONFIGURAZIONE di GovWay. La configurazione della connessione segue due modalità **automatiche e alternative** tra loro, scelte in base alla presenza o meno di `GOVWAY_DB_TYPE`:

* **variabili d'ambiente** (`GOVWAY_DB_TYPE` impostata): l'entrypoint genera a runtime le proprietà di connessione dalle variabili sotto elencate;
* **file di configurazione** (`GOVWAY_DB_TYPE` non impostata): il tool utilizza le properties già presenti in `/etc/govway` — quelle di default incluse nell'immagine, oppure quelle fornite dall'utente tramite un bind-mount su `/etc/govway` (o sul singolo file di properties del tool).

Variabili per la modalità a variabili d'ambiente:

* GOVWAY_DB_TYPE: Indica il tipo di database da utilizzare (valori ammessi: postgresql, mysql, mariadb, oracle, sqlserver)

  **NOTA:** Il database HSQL non è supportato: i tool operano su un database esterno già popolato, non su un'istanza file-based locale.

* GOVWAY_DB_SERVER: nome dns o ip address del server database (obbligatorio se GOVWAY_DB_TYPE è impostata)
* GOVWAY_DB_NAME: nome del database (obbligatorio se GOVWAY_DB_TYPE è impostata)
* GOVWAY_DB_USER: username da utilizzare per l'accesso al database (obbligatorio se GOVWAY_DB_TYPE è impostata)
* GOVWAY_DB_PASSWORD: password di accesso al database (obbligatorio se GOVWAY_DB_TYPE è impostata)
* GOVWAY_DS_JDBC_LIBS: path sul filesystem del container, ad una directory dove sono contenuti uno o più file jar necessari per l'interfacciamento al database

  ***AVVISO COMPORTAMENTO DEPRECATO: se non fornita e il database è PostgreSQL, viene utilizzato il driver JDBC interno all'immagine. Nelle prossime versioni sarà obbligatorio fornire le librerie attraverso GOVWAY_DS_JDBC_LIBS.***

  **NOTA:** `GOVWAY_DS_JDBC_LIBS` viene collegata al classpath del tool **solo** quando `GOVWAY_DB_TYPE` è impostata. Nella modalità "file di configurazione" (nessuna `GOVWAY_DB_TYPE`), il driver va fornito esportando direttamente la variabile del tool interessato (`TOOL_JDBC` per template-scan, `BATCH_JDBC` per config-loader, `VAULT_JDBC` per vault-cli) oppure montandolo dentro la relativa directory `jdbc/` dell'immagine.

* GOVWAY_DS_CONN_PARAM: parametri JDBC aggiuntivi da accodare alla url di connessione (default: vuoto)

Allo stesso modo delle variabili `*_JDBC`, la directory da cui ciascun tool legge le proprie properties può essere ridefinita tramite `BATCH_CONFIG` (config-loader), `TOOL_CONFIG` (template-scan) e `VAULT_CONFIG` (vault-cli); per default tutte e tre valgono `/etc/govway`.

#### Connessione a database Oracle ####
Quando ci si connette ad un database esterno Oracle deve essere indicata anche la seguente variabile d'ambiente

* GOVWAY_ORACLE_JDBC_URL_TYPE (SID/SERVICENAME): indica se connettersi ad un SID o ad un ServiceName Oracle (obbligatoria: a differenza dell'immagine principale e dell'immagine batch non viene assunto alcun valore di default)

#### Connessione a database SQL Server ####
Quando ci si connette ad un database esterno SQL Server è possibile configurare la cifratura a livello di trasporto tramite le stesse variabili d'ambiente descritte per l'immagine principale: GOVWAY_SQLSERVER_ENCRYPT, GOVWAY_SQLSERVER_TRUSTSTORE, GOVWAY_SQLSERVER_TRUSTSTORE_PASSWORD.
