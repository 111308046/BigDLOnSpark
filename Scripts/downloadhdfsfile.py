# importing the library
from snakebite.client import Client
  
# the below line create client connection to the HDFS NameNode
client = Client('10.129.2.179', 9000, sock_connect_timeout=50000, sock_request_timeout=50000)

avg = 0
n = 1  
# iterate over data.txt file and will show all the content of data.txt
for l in client.text(['/Mayur/customexecutorlogs/softmax.txt']):
        #print l
        all_lines = l.split("\n")
        for line in all_lines:
        	line = line.strip()
        	if line:
			#print(line)
			compl_time = line.split("=")
			#print("compl_time=", compl_time)
			time = int(compl_time[1])
			avg += (time - avg)/n
			n += 1
#print("n=", n)
#print("avg=", avg)
print(avg)
