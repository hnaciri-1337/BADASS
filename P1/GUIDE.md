## Build the two docker images
docker build -t badass-host /vagrant/Dockerfiles/host
docker build -t badass-router /vagrant/Dockerfiles/router

## Run the gns3 server on all interfaces

gns3server --host 0.0.0.0 --port 3080

## Access gns3 server on host browser VM_IP:3080
Go to prefernces then docker
Add the two images to and name them as shown in the subject
Create the project Part 1 and add the two images to it
Create a link between eth0 of the host and eth0 of the router
Start the project
Open console of the nodes

Configure the nodes to have an ip address on eth0

## router eth0
```bash
ip addr add 192.168.56.2/24 dev eth0
```
## host eth0
```
ip addr add 192.168.56.3/24 dev eth0
```

## Use nc to send a message from the host to the router

nc -l -p 1337

nc 192.168.56.2 -p 1337
