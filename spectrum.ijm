dummy = 1; //1開啟笨蛋模式 0開啟選單



close("*");
close("ROI Manager");
//close("*_.ijm", "keep");
titleDialog = "光譜校正";
image=getBoolean("開啟日光燈的光譜照片");
if (image==1) {
	open();}
else if (image==0) {}


width = getWidth();
height = getHeight();
titleCFL = getTitle();
selectionHeight = 20;

//紀錄cfl的資料夾
cflDir = File.directory;
cflOutputDir = cflDir + "CFL_output"+File.separator;
//如果CFL_output資料夾不存在就新增一個資料夾
if(!File.exists(cflOutputDir)){
	File.makeDirectory(cflOutputDir);
}


//取消過去的校正
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
//圖片原點歸零
run("Properties...", "channels=1 slices=1 frames=1 unit=pixel pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 origin=0");


//==========取中間高度20畫出selection，並getProfile得到Hue值==========
run("Specify...", "width=&width height=&selectionHeight x=0 y="+ height/2 -10 +"");
//此選取區轉HSB
run("Duplicate...", "title=HSB");
run("HSB Stack");
run("Select All");
hue = getProfile();
close("HSB");

//============取得profile數值==============
selectWindow(titleCFL);
y = getProfile();
n = y.length;
x = Array.getSequence(n);
tolerance = 10;
arrayMax = Array.findMaxima(y, tolerance);
arrayMax = Array.sort(arrayMax); //原本是數值排序，改用位置排序
nMax = arrayMax.length; //峰的數量

//==========在CFL2光譜照片上標記極大值==========
if(dummy == 0){
	selectWindow(titleCFL);
	run("Select None");
	run("Remove Overlay");
	for (i = 0; i < nMax; i++) {
		makePoint(arrayMax[i], height/2, "small yellow hybrid");
		run("Add Selection...");
	}
}else{}


//==========繪製spectrum==========
Plot.create("Spectrum", "Wavelength(nm)", "Intensity");
//Plot.setLimits(0, 90, -5, 80 );
//Plot.setFrameSize(700, 400)
Plot.setColor("black");
Plot.setLineWidth(1);
Plot.add("line", x, y);
Plot.setFontSize(14);


xValues = arrayMax; //極大值的X座標的array
yValues = newArray(nMax);  
peakNums = newArray(nMax); //峰的編號
for (i = 0; i < nMax; i++) {
	yValues[i] = y[arrayMax[i]];
	peakNums[i] = d2s(i, 0);
	
}


//==========在spectrum上面標示各峰的編號==========
//indexCode = "code: setFont('sanserif',14*s,'bold anti');drawString(d2s(i, 0),x-4*s,y+8*s);";
indexCode = "code: drawString(d2s(i, 0),x-4*s,y+8*s);";

Plot.setColor("red");
Plot.add(indexCode, xValues, yValues); 
Plot.setFormatFlags("0");
Plot.update()


//==========尋找各顏色的峰，其hue在特定範圍內，灰階值y最大。
//最後將此四個峰的x值存入array。分別是藍色1 藍色2 綠色 紅色
//利用HSB色彩空間尋找CFL的特定光譜峰方法:
//用Hue數值找出藍色、綠色、紅色的峰
//藍色hue:155-199
//綠藍之間的hue: 100-154
//綠色hue:60-100
//紅色hue:0-40 200-255 

peakX = newArray(4);      //四個峰的X值
peakOrder = newArray(4);  //四個峰的編號
maxGrayValueBlue1 = 0;
maxGrayValueBlue2 = 0;
maxGrayValueGreen = 0;
maxGrayValueRed = 0;

for (i = 0; i < nMax; i++) {
	//print(hue[arrayMax[i]]);
	if (hue[arrayMax[i]] > 155 && hue[arrayMax[i]] < 199 && y[arrayMax[i]] > maxGrayValueBlue1){
			maxGrayValueBlue1 = y[arrayMax[i]];
			peakX[0] = arrayMax[i];
			peakOrder[0] = i;
	}
	else if (hue[arrayMax[i]] > 100 && hue[arrayMax[i]] < 154 && y[arrayMax[i]] > maxGrayValueBlue2){
			maxGrayValueBlue2 = y[arrayMax[i]];
			peakX[1]  = arrayMax[i];
			peakOrder[1] = i;
	}	
	else if (hue[arrayMax[i]] > 60 && hue[arrayMax[i]] < 100 && y[arrayMax[i]] > maxGrayValueGreen){
			maxGrayValueGreen = y[arrayMax[i]];
			peakX[2] = arrayMax[i];
			peakOrder[2] = i;
	}
	else if ((hue[arrayMax[i]] > 200 || hue[arrayMax[i]] < 40 )&& y[arrayMax[i]] > maxGrayValueRed){
			maxGrayValueRed = y[arrayMax[i]];
			peakX[3] = arrayMax[i];
			peakOrder[3] = i;
	}	
}


//==========產生校正峰號碼和波長對照選單==========
knownLambda = newArray(436.5,487.7,546.5 ,611.6);

if (dummy == 1){
	x1 = arrayMax[peakOrder[0]];
	lambda1 = knownLambda[0];
	x2 = arrayMax[peakOrder[3]];
	lambda2 =  knownLambda[3];
	}
else{
	Dialog.create("輸入校正峰的波長");
	
	Dialog.addChoice("峰號碼", peakNums,peakOrder[0]);
	Dialog.addToSameRow();
	Dialog.addNumber("波長:",knownLambda[0]);
	
	Dialog.addChoice("峰號碼", peakNums,peakOrder[3]);
	Dialog.addToSameRow();
	Dialog.addNumber("波長:",knownLambda[3]);
	Dialog.addMessage("*下一步將選取待校正的資料夾");
	Dialog.show();
	
	//取得選單峰編號和波長
	x1 = Dialog.getChoice(); 
	lambda1 = Dialog.getNumber();
	x2 = Dialog.getChoice(); 
	lambda2 = Dialog.getNumber();
	
	//把峰編號放到arrayMax去尋找峰的X座標
	x1 = arrayMax[parseInt(x1)];  
	x2 = arrayMax[parseInt(x2)];
}



//計算波長和X座標的比例
deltaX = x2 - x1;
deltaLambda = lambda2 - lambda1;
scale = deltaLambda / deltaX ;


//==========數值校正===========
//將X值校正成光譜波長
for (i=0; i<x.length; i++){
	x[i] = lambda1 + (x[i]- x1) * scale;
	}

//校正峰值的x座標成光譜波長
for (i=0; i<xValues.length; i++){
	xValues[i] = lambda1 + (xValues[i]- x1) * scale;
	}

//標示峰波長
//indexCode = "code: setFont('sanserif',12*s,'bold anti');drawString(d2s(xval,1),x-4*s,y+8*s);";
indexCode = "code:drawString(d2s(xval,1),x-4*s,y+8*s);";




//==========用新的波長重繪CFL光譜圖SpectrumBelow==========
close("Spectrum");
Plot.create("SpectrumBelow", "Wavelength(nm)", "Intensity");
Plot.setLimits(400, 700, -100, 255 );
Plot.setFrameSize(600, 400)
Plot.setColor("black");
Plot.setLineWidth(1);
Plot.add("line", x, y);
Plot.setFontSize(14);
Plot.setFormatFlags("1000100001111");
//峰的標示
Plot.setColor("red");
Plot.add(indexCode, xValues, yValues); 
Plot.update()


//==========在原圖上切出目標光譜，並scale到特定大小存成temp2==========
selectWindow(titleCFL);
selectionWidth = 300/scale;
run("Specify...", "width=&selectionWidth height=&selectionHeight x="+  (400-lambda1)/scale+x1 +" y="+ height/2 -10 +"");
run("Set Measurements...", "area bounding redirect=None decimal=3");
run("Measure");
realWidth = getResult("Width", nResults-1);

//因有些光譜拍攝的範圍較小，故需測量selection的寬度，是否有達到 300/scale。
if(realWidth < selectionWidth ){
	selectionWidth = realWidth;
}


run("Duplicate...", "title=temp1");
spectrumWidth = parseInt(getWidth()*scale*2); //預設寬度為600
run("Scale...", "x=- y=- width=&spectrumWidth height=100 interpolation=Bilinear average create title=temp2");


//==========取得profile的原點和pixel size==========

selectWindow("SpectrumBelow");
ori1 = getTag("Coordinate origin");
index1 = indexOf(ori1,",");
oriX1 = parseInt( substring(ori1,0, index1));
oriY1 = parseInt( substring(ori1,index1+1,lengthOf(ori1)));

pixelSize1 = getTag("Pixel size");
index1 = indexOf(pixelSize1,"x");
index2 = indexOf(pixelSize1,"^");

pixelX1 = parseFloat( substring(pixelSize1,0, index1));
pixelY1 = parseFloat( substring(pixelSize1, index1+1 , index2 ));

function getTag(tag) {
  info = getImageInfo();
  index1 = indexOf(info, tag);
  if (index1==-1) return "";
  index1 = indexOf(info, ":", index1);
  if (index1==-1) return "";
  index2 = indexOf(info, "\n", index1);
  value = substring(info, index1+1, index2);
  return value;
}

//==========將光譜照片用overlay的方式放在profile==========

if(x[0]<400){
	startLambda1 = 400;
}else{
	startLambda1 = x[0];
}
startLambdaX1 = oriX1 + startLambda1 /pixelX1;//光譜profile的起點位置,ie. 400nm 的X座標是76
y255Pos1 = oriY1 - 255 /pixelY1;               //光譜profile在Y=255的y座標
//print(startLambdaX1);
//print(y255Pos1);

selectWindow("SpectrumBelow");
run("Add Image...", "image=temp2 x=&startLambdaX1 y=&oriY1 opacity=100");

run("Duplicate...", "title=CFL_Below");

close("SpectrumBelow");
//圖片原點和比例歸零
run("Properties...", "channels=1 slices=1 frames=1 unit=pixel pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 origin=0");



//清除y軸上-100的數值
setBackgroundColor(255, 255, 255);
makeRectangle(31, 323, 40, 102);
run("Clear", "slice");
run("Select None");
close("temp2");
saveAs("jpeg",cflOutputDir+"CFL_Below");
//============================================================
//==========用新的波長重繪CFL光譜圖SpectrumBackground==========

Plot.create("SpectrumBackground", "Wavelength(nm)", "Intensity");
Plot.setLimits(400, 700, 0, 255 );
Plot.setFrameSize(600, 400)
Plot.setColor("#ccccff");     
Plot.add("filled", x, y);

//Plot.setColor("black");
//Plot.setLineWidth(1);
//Plot.add("line", x, y);

Plot.setFontSize(14);
Plot.setFormatFlags("1000100001111");
//峰的標示
Plot.setColor("red");
Plot.add(indexCode, xValues, yValues); 
Plot.update()



//==========取得profile的原點和pixel size==========

selectWindow("SpectrumBackground");
ori2 = getTag("Coordinate origin");
index1 = indexOf(ori2,",");
oriX2 = parseInt( substring(ori2,0, index1));
oriY2 = parseInt( substring(ori2,index1+1,lengthOf(ori2)));

pixelSize2 = getTag("Pixel size");
index1 = indexOf(pixelSize2,"x");
index2 = indexOf(pixelSize2,"^");

pixelX2 = parseFloat( substring(pixelSize2,0, index1));
pixelY2 = parseFloat( substring(pixelSize2, index1+1 , index2 ));


if(x[0]<400){
	startLambda2 = 400;
}else{
	startLambda2 = x[0];
}
startLambdaX2 = oriX2 + startLambda2 /pixelX2;//光譜profile的起點位置,ie. 400nm 的X座標是76
y255Pos2 = oriY2 - 255 /pixelY2;               //光譜profile在Y=255的y座標
//print(startLambdaX2);
//print(y255Pos2);


selectWindow("SpectrumBackground");
doWand((oriX2 + 436/pixelX2), oriY2-5);//實際436nm的x座標 0y座標
roiManager("Add");
roiManager("Measure");
tempWidth = getWidth();
tempHeight = getHeight();
//==========temp1進行scale特定大小存成temp3==========

selectWindow("temp1");
run("Scale...", "x=- y=- width=&spectrumWidth height="+ 255/pixelY2  +" interpolation=Bilinear average create title=temp3");

newImage("tempSpec", "RGB", tempWidth, tempHeight, 1);

run("Add Image...", "image=temp3 x=&startLambdaX2 y=&y255Pos2 opacity=100");
Overlay.flatten;
close("temp3");
nROIs = roiManager("count");
roiManager("Select", nROIs-1);
rename("temp3");
run("Copy");
selectWindow("SpectrumBackground");
run("Paste");
run("Select None");
run("Duplicate...", "title=CFL_Background");
saveAs("jpeg",cflOutputDir+"CFL_Background");
close("SpectrumBackground");
//==========製作空白背景的profile==========

Plot.create("CFL_Blank", "Wavelength(nm)", "Intensity");
Plot.setLimits(400, 700, 0, 255 );
Plot.setFrameSize(600, 400)
Plot.setColor("black");
Plot.setLineWidth(2);
Plot.add("line", x, y);

Plot.setFontSize(14);
Plot.setFormatFlags("1000100001111");
//峰的標示
Plot.setColor("red");
Plot.add(indexCode, xValues, yValues); 
Plot.update()
saveAs("jpeg",cflOutputDir+"CFL_Blank");

//和其他temp3光譜圖做數學運算，取得其他類型的圖片
imageCalculator("Subtract create", "temp3","CFL_Blank");
rename("CFL_Substract");
saveAs("jpeg",cflOutputDir+"CFL_Substract");

imageCalculator("Average create", "temp3","CFL_Blank");
rename("CFL_Average");
saveAs("jpeg",cflOutputDir+"CFL_Average");
//==========製作太陽光譜當背景==========
close("*");
newImage("Red", "8-bit black", 100, 1, 1);
rArray = newArray(9,9,10,11,10,11,11,7,6,5,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,2,23,62,93,108,112,116,118,116,115,113,109,103,96,90,85,80,
75,70,64,61,59,58,56,53,53,54,55,55,54,49,40,30,17,9,6,5,3,3,2,2,2,2,2,2,2,2);
for(m = 0; m<100;m++){
	setPixel(m,0,rArray[m]);
}

newImage("Green", "8-bit black", 100, 1, 1);
gArray = newArray(0,0,0,0,0,0,0,0,0,0,0,1,6,7,16,28,41,58,78,99,119,132,141,142,
138,141,140,141,145,149,150,157,160,160,160,160,160,160,160,160,
160,158,154,153,150,146,142,136,130,124,118,111,106,100,93,86,76,
62,49,38,31,28,21,14,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,
5,6,6,5,3,3,2,2,2,2,2,2,2,2);
for(m = 0; m<100;m++){
	setPixel(m,0,gArray[m]);
}

newImage("Blue", "8-bit black", 100, 1, 1);
bArray = newArray(190,197,205,213,221,228,236,244,251,255,255,255,255,255,255,
255,255,255,255,255,255,255,255,255,255,253,242,228,214,200,
186,172,156,136,111,83,56,39,29,22,13,4,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,8,7,7,8,9,8,10,11,11,11,14,16,
17,17,15,14,12,9,7,6,5,3,3,2,2,2,2,2,2,2,2);
for(m = 0; m<100;m++){
	setPixel(m,0,bArray[m]);
}


run("Images to Stack", "name=Stack title=[] use");
run("RGB Color");
run("Scale...", "x=- y=- width=&spectrumWidth height="+ 255/pixelY2  +" interpolation=Bilinear average create title=solar_temp");
close("Stack");

newImage("tempSpec", "RGB", tempWidth, tempHeight, 1);

run("Add Image...", "image=solar_temp x=&startLambdaX2 y=&y255Pos2 opacity=100");
Overlay.flatten;
rename("solar");


//==========拿solor和CFL_Blank做數學運算========
open(cflOutputDir+"CFL_Blank.jpg");
rename("CFL_Blank");

imageCalculator("Subtract create", "solar","CFL_Blank");
rename("CFL_Solar_Substract");
saveAs("jpeg",cflOutputDir+"CFL_Solar_Substract");

imageCalculator("Average create", "solar","CFL_Blank");
rename("CFL_Solar_Average");
saveAs("jpeg",cflOutputDir+"CFL_Solar_Average");

//==========關閉圖片==========
close("temp*");
close(titleCFL);

//run("Images to Stack", "name=Stack title=[] use");
close("*");

close("Results");
close("ROI Manager");
//====================================
//==========開啟等待校正的資料夾==========
//====================================
waitCali = getBoolean("選擇待校正的照片資料夾");
if (waitCali == 1) {
	caliDir = getDirectory("選擇待校正的照片資料夾 ");
	list = getFileList(caliDir);
	}
else if (waitCali == 0) {};


//==========在待校正資料夾中新增數個資料夾
type = newArray("Average","Background","Below","Substract","Blank","Solar_Substract","Solar_Average");
for(j = 0; j<type.length;j++){
	imgOutputDir = caliDir + type[j] + File.separator;
	//如果output資料夾不存在就新增一個資料夾
	if(!File.exists(imgOutputDir)){
	File.makeDirectory(imgOutputDir);
	}	
}



//======在list中去除"資料夾"======
imgPath = newArray(0);
for (i = 0; i < list.length; i++){
	if(!File.isDirectory(caliDir +list[i])){
		imgPath = append(imgPath, caliDir +list[i]);

	}else{}
	
}
function append(arr, value) {
	arr2 = newArray(arr.length+1);
	for (i=0; i<arr.length; i++)
	arr2[i] = arr[i];
	arr2[arr.length] = value;
	return arr2;
}
//===============================

for (i = 0; i < imgPath.length; i++){

	close("*");
	close("ROI Manager");
	open(imgPath[i]);
	//print(imgPath[i]);
	titleImg = getTitle();
	

	//取消過去的校正
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	//圖片原點歸零
	run("Properties...", "channels=1 slices=1 frames=1 unit=pixel pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 origin=0");

	//==========取中間高度20畫出selection，並getProfile==========
	run("Specify...", "width=&width height=&selectionHeight x=0 y="+ height/2 -10 +"");

	//============取得profile數值==============	
	y = getProfile();
	n = y.length;
	x = Array.getSequence(n);


	//==========數值校正===========
	//將X值校正成光譜波長
	for (j=0; j<x.length; j++){
		x[j] = lambda1 + (x[j]- x1) * scale;
		}
	//==========用新的波長重繪CFL光譜圖SpectrumBelow==========
	
	Plot.create("SpectrumBelow", "Wavelength(nm)", "Intensity");
	Plot.setLimits(400, 700, -100, 255 );
	Plot.setFrameSize(600, 400)
	Plot.setColor("black");
	Plot.setLineWidth(1);
	Plot.add("line", x, y);
	Plot.setFontSize(14);
	Plot.setFormatFlags("1000100001111");	
	Plot.update();
	
	//==========在原圖上切出目標光譜，並scale到特定大小存成temp2==========


	
	selectWindow(titleImg);
	
	run("Specify...", "width=&selectionWidth height=&selectionHeight x="+  (400-lambda1)/scale+x1 +" y="+ height/2 -10 +"");

	run("Duplicate...", "title=temp1");
	run("Scale...", "x=- y=- width=&spectrumWidth height=100 interpolation=Bilinear average create title=temp2");

	selectWindow("SpectrumBelow");
	run("Add Image...", "image=temp2 x=&startLambdaX1 y=&oriY1 opacity=100");
	run("Duplicate...", "title=Below");

	
	//close("SpectrumBelow");
	//圖片原點和比例歸零
	run("Properties...", "channels=1 slices=1 frames=1 unit=pixel pixel_width=1.0000 pixel_height=1.0000 voxel_depth=1.0000 origin=0");
	
	//清除y軸上-100的數值
	setBackgroundColor(255, 255, 255);
	makeRectangle(31, 323, 40, 102);
	run("Clear", "slice");
	run("Select None");
	close("temp2");
	saveAs("jpeg" , caliDir + "Below" + File.separator + titleImg);
	close("SpectrumBelow");
//*****************************************************************************************	
	//============================================================
	//==========用新的波長重繪CFL光譜圖SpectrumBackground==========

	Plot.create("SpectrumBackground", "Wavelength(nm)", "Intensity");
	Plot.setLimits(400, 700, 0, 255 );
	Plot.setFrameSize(600, 400)
	Plot.setColor("#ccccff");     
	Plot.add("filled", x, y);

	

	Plot.setFontSize(14);
	Plot.setFormatFlags("1000100001111");
	Plot.update();

	//==========取得profile的原點和pixel size==========
	
	selectWindow("SpectrumBackground");
	doWand((oriX2 + 436/pixelX2), oriY2-5);//實際436nm的x座標 0y座標
	roiManager("Add");
	roiManager("Measure");
	tempWidth = getWidth();
	tempHeight = getHeight();
	//==========temp1進行scale特定大小存成temp3==========
	
	selectWindow("temp1");
	run("Scale...", "x=- y=- width=&spectrumWidth height="+ 255/pixelY2  +" interpolation=Bilinear average create title=temp3");
	newImage("tempSpec", "RGB", tempWidth, tempHeight, 1);
	
	run("Add Image...", "image=temp3 x=&startLambdaX2 y=&y255Pos2 opacity=100");
	Overlay.flatten;
	close("temp3");
	nROIs = roiManager("count");
	roiManager("Select", nROIs-1);
	rename("temp3");
	run("Copy");
	selectWindow("SpectrumBackground");
	run("Paste");
	run("Select None");
	run("Duplicate...", "title=CFL_Background");
	saveAs("jpeg",caliDir + "Background" + File.separator + titleImg);
	close("SpectrumBackground");
//==========製作空白背景的profile==========

	Plot.create("Blank", "Wavelength(nm)", "Intensity");
	Plot.setLimits(400, 700, 0, 255 );
	Plot.setFrameSize(600, 400)
	Plot.setColor("black");
	Plot.setLineWidth(2);
	Plot.add("line", x, y);
	
	Plot.setFontSize(14);
	Plot.setFormatFlags("1000100001111");
	Plot.update();
	saveAs("jpeg",caliDir + "Blank" + File.separator + titleImg);
	
	//和其他temp3光譜圖做數學運算，取得其他類型的圖片
	imageCalculator("Subtract create", "temp3","Blank");
	rename("Substract");
	saveAs("jpeg",caliDir + "Substract" + File.separator + titleImg);
	
	imageCalculator("Average create", "temp3","Blank");
	rename("Average");
	saveAs("jpeg",caliDir + "Average" + File.separator + titleImg);
	close("*");
	//==========製作太陽光譜當背景==========

	newImage("Red", "8-bit black", 100, 1, 1);
	rArray = newArray(9,9,10,11,10,11,11,7,6,5,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,2,23,62,93,108,112,116,118,116,115,113,109,103,96,90,85,80,
	75,70,64,61,59,58,56,53,53,54,55,55,54,49,40,30,17,9,6,5,3,3,2,2,2,2,2,2,2,2);
	for(m = 0; m<100;m++){
		setPixel(m,0,rArray[m]);
	}
	
	newImage("Green", "8-bit black", 100, 1, 1);
	gArray = newArray(0,0,0,0,0,0,0,0,0,0,0,1,6,7,16,28,41,58,78,99,119,132,141,142,
	138,141,140,141,145,149,150,157,160,160,160,160,160,160,160,160,
	160,158,154,153,150,146,142,136,130,124,118,111,106,100,93,86,76,
	62,49,38,31,28,21,14,8,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,
	5,6,6,5,3,3,2,2,2,2,2,2,2,2);
	for(m = 0; m<100;m++){
		setPixel(m,0,gArray[m]);
	}
	
	newImage("Blue", "8-bit black", 100, 1, 1);
	bArray = newArray(190,197,205,213,221,228,236,244,251,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,253,242,228,214,200,
	186,172,156,136,111,83,56,39,29,22,13,4,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,7,8,7,7,8,9,8,10,11,11,11,14,16,
	17,17,15,14,12,9,7,6,5,3,3,2,2,2,2,2,2,2,2);
	for(m = 0; m<100;m++){
		setPixel(m,0,bArray[m]);
	}
	
	
	run("Images to Stack", "name=Stack title=[] use");
	run("RGB Color");
	run("Scale...", "x=- y=- width=&spectrumWidth height="+ 255/pixelY2  +" interpolation=Bilinear average create title=solar_temp");
	close("Stack");
	
	newImage("tempSpec", "RGB", tempWidth, tempHeight, 1);
	
	run("Add Image...", "image=solar_temp x=&startLambdaX2 y=&y255Pos2 opacity=100");
	Overlay.flatten;
	rename("solar");

	//==========拿solor和CFL_Blank做數學運算========
	open(caliDir + "Blank" + File.separator + titleImg);
	rename("Blank");
	
	imageCalculator("Subtract create", "solar","Blank");
	rename("Solar_Substract");
	saveAs("jpeg",caliDir + "Solar_Substract" + File.separator + titleImg);
	
	imageCalculator("Average create", "solar","Blank");
	rename("Solar_Average");
	saveAs("jpeg",caliDir + "Solar_Average" + File.separator + titleImg);


	
}

close("*");
close("ROI Manager");
close("Results");
