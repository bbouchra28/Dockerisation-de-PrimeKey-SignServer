import requests
import argparse


parser = argparse.ArgumentParser()
parser.add_argument("--pdf" , help="Le fichier pdf a signer, chemin absolue")
parser.add_argument("--host" , help="url vers SignServer")
parser.add_argument("--password" , help="mot de passe de pdf s'il est protégé")
parser.add_argument("--worker" , help="Id du worker")
args = parser.parse_args()

if [args.password]:
	password = args.password
else:
	password = ""
	
print (password)
params = {
                            'workerName': 'PDFSigner'       ,
                            'workerId': args.worker         ,
                            'pdfPassword': password         ,
                            'processType': 'signDocument'   ,
        }

pdffiles = {'filerecievefile': open(args.pdf, 'rb') }

url = args.host + '/signserver/process'

r = requests.post(url, data=params, files=pdffiles)

file = open("out.pdf", "wb")
file.write(r.content)
file.close()
