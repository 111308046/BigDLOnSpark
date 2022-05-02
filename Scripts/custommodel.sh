BigDLFolder=~/MTP/ForkedRepoBigDL/BigDL
linearTemplateFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Model1_linear.template
convTemplateFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Model1_conv.template
utilsTemplateFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Utils.template
trainTemplateFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Train.template
modelFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Model1.scala
utilsFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Utils.scala
trainFile=~/MTP/ForkedRepoBigDL/BigDL/spark/dl/src/main/scala/com/intel/analytics/bigdl/models/mymodel/Train.scala

while IFS=","
	read config epoch datasize batchsize input_width input_height input_dim output_dim max_core executor_cores task_cpus driver_core executor_instances driver_memory executor_memory parallelism

do 

	echo -e "\e[1;31m RUNNING CONFIG \#$config" 
	echo -e "--------------------------------------------------- \e[0m"
	echo step 1/10 !!!!!!!!Copying the skeleton file!!!!!!
	cp $linearTemplateFile $modelFile
	cp $utilsTemplateFile $utilsFile
	cp $trainTemplateFile $trainFile

	echo step 2/10 !!!!!!!!Filling up the parameter in the model!!!!!!!!!!
	sed -i "s/%%input_dim%%/$input_dim/g" $modelFile
	sed -i "s/%%output_dim%%/$output_dim/g" $modelFile
	
	echo !!!!!!!!!! Filling up the parameters in the Utils file !!!!!!!!!!
	sed -i "s/%%input_width%%/$input_width/g" $utilsFile
	sed -i "s/%%input_height%%/$input_height/g" $utilsFile
	
	echo !!!!!!!!!! Filling up the parameters in the Train file !!!!!!!!!!
	sed -i "s/%%input_width%%/$input_width/g" $trainFile
	sed -i "s/%%input_height%%/$input_height/g" $trainFile
	sed -i "s/%%output_dim%%/$output_dim/g" $trainFile
	
	echo step 3/10 !!!!!!!starting compilation!!!!!!!!
	cd $BigDLFolder
	bash make-dist.sh
	
	echo step 4/10 !!!!!!copying JAR file to the server!!!!!!!!
	sshpass -e scp  $BigDLFolder/dist/lib/bigdl-SPARK_2.0-0.13.0-SNAPSHOT-jar-with-dependencies.jar etcd@10.129.2.179:~/NASDrive/BigDL/dist/lib > /home/mayur/MTP/automateBigDL/MTP2/temp.log
	
	echo step 5/10 !!!!!!!uploading jar file to hadoop server!!!!!!!!

	sshpass -e ssh -n hduser@10.129.2.179 "/home/etcd/NASDrive/hadoop/bin/hadoop dfs -copyFromLocal -f /home/etcd/NASDrive/BigDL/dist/lib/bigdl-SPARK_2.0-0.13.0-SNAPSHOT-jar-with-dependencies.jar /jars/BigDL" > /home/mayur/MTP/automateBigDL/MTP2/temp.log

	echo step 6/10 !!!!!!!Modifying the run file!!!!!!!!
	
	sshpass -e ssh -n spark@10.129.2.177 "cd mayur && cp job.template job.sh && sed -i \"s/%%epoch%%/$epoch/g\" job.sh && sed -i \"s/%%datasize%%/$datasize/g\" job.sh &&  sed -i \"s/%%batchsize%%/$batchsize/g\" job.sh && cat job.sh"  > /home/mayur/MTP/automateBigDL/MTP2/temp.log
	
	echo step 7/10 !!!!!!!!!Setting up the spark parameters!!!!!!!!!
	sshpass -e ssh -n spark@10.129.2.177 "cd mayur && cp properties.template properties.conf && sed -i \"s/%%max_core%%/$max_core/g\" properties.conf &&   sed -i \"s/%%driver_core%%/$driver_core/g\" properties.conf && sed -i \"s/%%executor_cores%%/$executor_cores/g\" properties.conf &&  sed -i \"s/%%task_cpus%%/$task_cpus/g\" properties.conf &&  sed -i \"s/%%executor_instances%%/$executor_instances/g\" properties.conf &&  sed -i \"s/%%driver_memory%%/$driver_memory/g\" properties.conf &&  sed -i \"s/%%executor_memory%%/$executor_memory/g\" properties.conf && sed -i \"s/%%podname%%/custommodel$config/g\" properties.conf && sed -i \"s/%%parallelism%%/$parallelism/g\" properties.conf && cat properties.conf" > /home/mayur/MTP/automateBigDL/MTP2/temp.log
	
	a=$((config-1))
	echo step 8/10 !!!!!!!Deleting the exisiting pods and running the job!!!!!!!!
	timeout 1m sshpass -e ssh -n spark@10.129.2.177 "kubectl delete pods custommodel$a" > /home/mayur/MTP/automateBigDL/MTP2/temp.log 
	timeout 1m sshpass -e ssh -n spark@10.129.2.177 "kubectl delete pods custommodel$a" > /home/mayur/MTP/automateBigDL/MTP2/temp.log 
	echo step 8/10 !!!!!!!running the job!!!!!!!!
	timeout 10m sshpass -e ssh -n spark@10.129.2.177 "cd mayur && ./job.sh" >  /home/mayur/MTP/automateBigDL/MTP2/temp.log
	
	echo step 9/10 !!!!!!!Capturing the output!!!!!!!!
	dataLoadingTime=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs custommodel$config |  sed -n '/Time took to load the data/{n;p;}' ")
	valDataLoadTime=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs custommodel$config |  sed -n '/Time took to load the validation data/{n;p;}' ")
	dataCacheTime=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs custommodel$config |  sed -n '/dataload Cache time/{n;p;}' " | tr "\n" ",")
	result=$(sshpass -e ssh -n spark@10.129.2.177 "kubectl logs custommodel$config | grep InstrumentationResult")
	
	sshpass -e ssh -n spark@10.129.2.177 "kubectl logs custommodel$config" > /home/mayur/MTP/automateBigDL/MTP2/logs/$config
	

	echo step 10/10 !!!!!!!Storing the result!!!!!!!!
	
	#getting avg from custom logs for softmax
	cd -
	source ~/python2venv/bin/activate
	softmaxTime=$(python downloadhdfsfile.py)
	deactivate
	
	echo "$config,$epoch,$datasize,$batchsize,$input_width,$input_height,$input_dim,$output_dim,$max_core,$executor_cores,$task_cpus,$driver_core,$executor_instances,$driver_memory,$executor_memory,$parallelism,$dataLoadingTime,$valDataLoadTime,$softmaxTime,$result" >>output.csv
	echo -------------------------------------------------
done < <(tail -n +2 /home/mayur/MTP/automateBigDL/MTP2/jobrun/LinearInputData_30apr.csv)
cat output.csv >> pers.csv


	
	
	
	

