#!/bin/bash
APPSRV_HOME=/opt/wildfly
SIGNSERVER_NODEID=node1
bash /opt/signserver/bin/signserver setproperties /opt/signserver/doc/sample-configs/keystore-crypto.properties
bash /opt/signserver/bin/signserver setproperty 1 KEYSTOREPATH /opt/signserver/res/test/dss10/dss10_keystore.p12
bash /opt/signserver/bin/signserver setproperty 1 KEYSTOREPASSWORD $1
bash /opt/signserver/bin/signserver setproperty 1 DEFAULTKEY $2
bash /opt/signserver/bin/signserver reload 1
bash /opt/signserver/bin/signserver setproperties /opt/signserver/doc/sample-configs/plainsigner.properties
bash /opt/signserver/bin/signserver reload 2
bash /opt/signserver/bin/signserver setproperties /opt/signserver/doc/sample-configs/cmssigner.properties
bash /opt/signserver/bin/signserver reload 3
bash /opt/signserver/bin/signserver setproperties /opt/signserver/doc/sample-configs/pdfsigner.properties
bash /opt/signserver/bin/signserver reload 4
