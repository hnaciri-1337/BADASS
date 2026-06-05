## Build the two docker images
docker build -t badass-host /vagrant/Dockerfiles/host
docker build -t badass-router /vagrant/Dockerfiles/router

### Purpose
Build the Docker images used for the host and router containers in the GNS3 topology.

### Command Breakdown
* `docker build -t badass-host /vagrant/Dockerfiles/host` builds the host image and tags it as `badass-host`.
* `docker build -t badass-router /vagrant/Dockerfiles/router` builds the router image and tags it as `badass-router`.

### Result
The images required to instantiate the GNS3 host and router nodes are created and ready for use.

## Run the gns3 server on all interfaces

gns3server --host 0.0.0.0 --port 3080

### Purpose
Start the GNS3 server so it listens for project connections on all network interfaces.

### Command Breakdown
* `gns3server` launches the GNS3 server process.
* `--host 0.0.0.0` binds the service to all local interfaces.
* `--port 3080` listens on TCP port 3080.

### Result
The GNS3 server becomes available to remote and local clients on the specified port.

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

### Purpose
Assign the router’s eth0 interface an IP address on the host subnet used in the GNS3 lab.

### Command Breakdown
* `192.168.56.2/24` configures the router’s IPv4 address and subnet mask.
* `dev eth0` specifies the connected interface.

### Result
The router can communicate with the host over the emulated LAN in the GNS3 project.

## host eth0
```
ip addr add 192.168.56.3/24 dev eth0
```

### Purpose
Assign the host’s eth0 interface an IP address in the same subnet as the router.

### Command Breakdown
* `192.168.56.3/24` sets the host’s IP address and subnet.
* `dev eth0` specifies the host’s network interface.

### Result
The host is on the same LAN as the router and can send traffic to it.

## Use nc to send a message from the host to the router

nc -l -p 1337

### Purpose
Start a TCP listener on the router to receive a message from the host.

### Command Breakdown
* `nc -l -p 1337` listens on TCP port 1337 for incoming connections.

### Result
The router is ready to accept a TCP connection from the host.

nc 192.168.56.2 -p 1337

### Purpose
Connect from the host to the router’s listening port to verify end-to-end TCP reachability.

### Command Breakdown
* `nc 192.168.56.2 -p 1337` opens a TCP connection to the router at port 1337.

### Result
The host establishes a direct TCP session to the router, proving the network path is functional.
