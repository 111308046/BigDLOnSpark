BigDLFolder=~/MTP/ForkedRepoBigDL/BigDL
templateFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/lenet/LeNet5.template
targetFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/lenet/LeNet5.scala
echo ""> output.csv
while IFS="," 
	read config epoch batchsize datasize filter first_conv_kernel second_conv_kernel output_height output_width dense_layer max_core	driver_core executor_cores task_cpus executor_instances	driver_memory executor_memory memory_fraction storage_fraction parallelism

do
	echo -e "\e[1;31m RUNNING CONFIG \#$config" 
	echo -e "--------------------------------------------------- \e[0m"
	echo step 1/10 !!!!!!!!Copying the skeleton file!!!!!!
	cp $templateFile $targetFile

	echo step 2/10 !!!!!!!!Filling up the parameter in the model!!!!!!!!!!
	sed -i "s/%%filter%%/$filter/g" $targetFile
	sed -i "s/%%first_conv_kernel%%/$first_conv_kernel/g" $targetFile
	sed -i "s/%%second_conv_kernel%%/$second_conv_kernel/g" $targetFile
	sed -i "s/%%output_height%%/$output_height/g" $targetFile
	sed -i "s/%%output_width%%/$output_width/g" $targetFile
	sed -i "s/%%dense_layer%%/$dense_layer/g" $targetFile
	echo step 3/10 !!!!!!!starting compilation!!!!!!!!
	cd $BigDLFolder
	bash make-dist.sh > /home/mayur/MTP/automateBigDL/temp.log
	
	echo step 4/10 !!!!!!copying JAR file to the server!!!!!!!!
	sshpass -e scp  $BigDLFolder/dist/lib/bigdl-SPARK_2.0-0.13.0-SNAPSHOT-jar-with-dependencies.jar etcd@10.129.2.179:~/NASDrive/BigDL/dist/lib > /home/mayur/MTP/automateBigDL/temp.log
	
	echo step 5/10 !!!!!!!uploading jar file to hadoop server!!!!!!!!

	sshpass -e ssh -n hduser@10.129.2.179 "/home/etcd/NASDrive/hadoop/bin/hadoop dfs -copyFromLocal -f /home/etcd/NASDrive/BigDL/dist/lib/bigdl-SPARK_2.0-0.13.0-SNAPSHOT-jar-with-dependencies.jar /jars/BigDL" > /home/mayur/MTP/automateBigDL/temp.log
	
	echo step 6/10 !!!!!!!Modifying the run file!!!!!!!!
	
	sshpass -e ssh -n spark@10.129.2.177 "cd shailesh && cp job.template job.sh && sed -i \"s/%%epoch%%/$epoch/g\" job.sh && sed -i \"s/%%datasize%%/$datasize/g\" job.sh &&  sed -i \"s/%%batchsize%%/$batchsize/g\" job.sh && cat job.sh"  > /home/mayur/MTP/automateBigDL/temp.log
	
	echo step 7/10 !!!!!!!!!Setting up the spark parameters!!!!!!!!!
	sshpass -e ssh -n spark@10.129.2.177 "cd shailesh && cp properties.template properties.conf && sed -i \"s/%%max_core%%/$max_core/g\" properties.conf &&   sed -i \"s/%%driver_core%%/$driver_core/g\" properties.conf && sed -i \"s/%%executor_cores%%/$executor_cores/g\" properties.conf &&  sed -i \"s/%%task_cpus%%/$task_cpus/g\" properties.conf &&  sed -i \"s/%%executor_instances%%/$executor_instances/g\" properties.conf &&  sed -i \"s/%%driver_memory%%/$driver_memory/g\" properties.conf &&  sed -i \"s/%%executor_memory%%/$executor_memory/g\" properties.conf &&  sed -i \"s/%%memory_fraction%%/$memory_fraction/g\" properties.conf && sed -i \"s/%%podname%%/vgg$config/g\" properties.conf && sed -i \"s/%%storage_fraction%%/$storage_fraction/g\" properties.conf &&  sed -i \"s/%%parallelism%%/$parallelism/g\" properties.conf && cat properties.conf" > /home/mayur/MTP/automateBigDL/temp.log	

	

	a=$((config-1))
	echo step 8/10 !!!!!!!Deleting the exisiting pods and running the job!!!!!!!!
	timeout 1m sshpass -e ssh -n spark@10.129.2.177 "kubectl delete pods vgg$a" > /home/mayur/MTP/automateBigDL/temp.log 
	timeout 1m sshpass -e ssh -n spark@10.129.2.177 "kubectl delete pods vgg$a" > /home/mayur/MTP/automateBigDL/temp.log 
	echo step 8/10 !!!!!!!running the job!!!!!!!!
	timeout 10m sshpass -e ssh -n spark@10.129.2.177 "cd shailesh && ./job.sh" >  /home/mayur/MTP/automateBigDL/temp.log


 
	echo step 9/10 !!!!!!!Capturing the output!!!!!!!!
	dataLoadingTime=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs vgg$config |  sed -n '/Time took to load the data/{n;p;}' ")
	valDataLoadTime=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs vgg$config |  sed -n '/Time took to load the validation data/{n;p;}' ")
	dataCacheTime=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs vgg$config |  sed -n '/dataload Cache time/{n;p;}' " | tr "\n" ",")
	result=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs vgg$config | grep InstrumentationResult")
	
	
	sshpass -e ssh -n spark@10.129.2.177 "kubectl logs vgg$config" > /home/mayur/MTP/automateBigDL/logs/$config
	echo step 10/10 !!!!!!!Storing the result!!!!!!!!
	
	cd - && echo "$config,$epoch,$batchsize,$filter,$first_conv_kernel,$second_conv_kernel,$output_height,$output_width,$dense_layer,$max_core,$driver_core,$executor_cores,$task_cpus,$executor_instances,$driver_memory,$executor_memory,$memory_fraction,$storage_fraction,$parallelism,$dataLoadingTime,$valDataLoadTime,$result" >>output.csv
	echo -------------------------------------------------
done < <(tail -n +2 /home/mayur/MTP/automateBigDL/ModelSheet5.csv)
cat output.csv >> pers.csv
