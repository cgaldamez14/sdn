# SDN Project

## Description
A network simulation to test a Software-Defined Network(SDN)


## How to run the program

- Set up trema-edge on your computer. Follow the instructions on <code>https://github.com/trema/trema-edge.git</code>
- Clone <code>https://github.com/cgaldamez14/sdn.git</code> to the root of your trema-edge directory
- Open two terminals
  - On the first terminal run the following command:<br>
      <code>./trema run sdn/MyController.rb -c sdn/MyController.conf</code>
  - On the second terminal run the following command:<br>
      <code>./trema send_packets --source <host_name> --dest <host_name> [optional]--n_pkts <#_of_packets_to_send></code><br><br>
NOTE: Name of host are set in <code> https://github.com/cgaldamez14/sdn/blob/master/MyController.conf </code><br><br>
  - If you wish to see how many packets were sent and received by a certain host, run the following command on the second terminal:<br>
      <code>./trema show_stats <host_name> </code>

### Group Members

Carlos Galdamez<br>
Jose Rivas<br>
Eduardo Lopez-Serrano
