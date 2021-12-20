# Systolic_Array

Created a Systolic Array and its controller which utilises it in a weight stationary fashion. 
Combined activation and data FIFOs to a single unit (represented as L0 in diagram) for ease of implementation

System Description

* Corelet : It which has the controller, systolic array, SFUs (Special Function Units) & auxilliary FIFO based interfaces connected within it
* Core : Tying to corelet module to the input and output SRAMs as well as the testbench
* core_tb.sv (Testbench) : Reading data from text files; triggering the start of execution; comparing output to golden vectors

<img src="https://user-images.githubusercontent.com/32195473/146703780-3984e66a-0590-4a19-9ef8-78d8ab14f6b7.png" width=75% height=75%>

Directory Guide
* src : Contains all the RTL files for the entire design
* sim : Contains the Testbench, filelist, waveforms along with the input/output text vectors
