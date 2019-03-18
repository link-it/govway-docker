![GovWay](https://govway.org/assets/images/gway_logo.svg "L'API gateway per la pubblica amministrazione italiana")
# Tags supportati e link ai rispettivi Dockerfile
* [3.0.1, latest (standalone_bin/Dockerfile)](https://github.com/link-it/govway-docker/blob/master/standalone_bin/Dockerfile)

# Riferimenti al progetto
* [Informazioni sul progetto GovWay](https://govway.org/)
* [Sorgenti GovWay su GitHub](https://github.com/link-it/govway)
* [Progetto Govway-Docker su GitHub][3]

# Come utilizzare l'immagine

## Avviare l'immagine

L'avvio minimo deve essere fatto nella seguente maniera:

docker run -p 8080:8080 linkitaly/govway

Attraverso la porta 8080 e' possible accedere ai servizi ed alle interfacce di configurazione e monitoraggio:

* __*http://localhost:8080/govway/api/in*__ (o http://host-ip:8080/govway/api/in)
* __*http://localhost:8080/govway/api/out*__ (o http://host-ip:8080/govway/api/out)
* __*http://localhost:8080/pddConsole*__ (o http://host-ip:8080/pddConsole)
* __*http://localhost:8080/pddMonitor*__ (o http://host-ip:8080/pddMonitor)

Per maggiori informazioni sull'utilizzo fare riferimento alla documentazione del progetto [Govway-Docker][3] e alla manualistica presente su [Govway.org](https://govway.org/download).


I files interni utilizzati da GovWay: le properties di configurazione, i certificati SSL di esempio, il database HSQL ed i file di log, sono posizionati tutti sotto la directory standard /var/govway; si possono quindi rendere tutti persistenti montando un volume vuoto su questa directory

```console
mkdir ~/govway_home
docker run -v ~/govway_home:/var/govway -p 8080:8080 linkitaly/govway
```

## Personalizzare l'avvio
E' possibile personalizzare l'immagine all'avvio impostando alcune variabili d'ambiente. Al momento sono supportate le seguenti:
* __**FQDN**__: utilizzato per personalizzare il campo *CN* del subject dei certificati generati; se non specificato viene usato il valore di default *test.govway.org*
* __**USERID**__: utilizzato per impostare l'id di sistema dell'utente tomcat
* __**GROUPID**__: utilizzato per impostare l'id di sistema dell'utente tomcat

[3]: https://github.com/link-it/govway-docker "Progetto Govway-Docker"
