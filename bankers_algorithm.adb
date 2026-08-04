--  bankers_algorithm.adb
--  
--  Ada implementation of the Banker's Algorithm for deadlock avoidance
--  Based on: https://en.wikipedia.org/wiki/Banker's_algorithm
--  
--  This package body provides a complete implementation of the Banker's Algorithm
--  including all variants: Non-Preemptive, Preemptive, Static, and Dynamic.
--  
--  Author: Vibe Code (Mistral AI)
--  Date: 2024

package body Bankers_Algorithm is

   --  ====================================================================
   --  HELPER FUNCTIONS (Private)
   --  ====================================================================

   --  Check if all elements in a vector are <= corresponding elements in another
   function "<=" (Left, Right : Resource_Vector) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      
      for I in Left'Range loop
         if Left(I) > Right(I) then
            return False;
         end if;
      end loop;
      return True;
   end "<=";

   --  Check if all elements in a vector are < corresponding elements in another
   function "<" (Left, Right : Resource_Vector) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      
      for I in Left'Range loop
         if Left(I) >= Right(I) then
            return False;
         end if;
      end loop;
      return True;
   end "<";

   --  Add two resource vectors
   function "+" (Left, Right : Resource_Vector) return Resource_Vector is
      Result : Resource_Vector (Left'Range);
   begin
      for I in Left'Range loop
         Result(I) := Left(I) + Right(I);
      end loop;
      return Result;
   end "+";

   --  Subtract two resource vectors
   function "-" (Left, Right : Resource_Vector) return Resource_Vector is
      Result : Resource_Vector (Left'Range);
   begin
      for I in Left'Range loop
         Result(I) := Left(I) - Right(I);
      end loop;
      return Result;
   end "-";

   --  ====================================================================
   --  BASIC OPERATIONS
   --  ====================================================================

   --  Initialize a system state with given parameters
   function Initialize_System (
      Num_Processes  : Process_Index;
      Num_Resources  : Resource_Index;
      Total_Resources : Resource_Vector)
      return System_State is
   begin
      --  Validate input
      if Num_Processes <= 0 then
         raise No_Processes_Exception with "Number of processes must be positive";
      end if;
      
      if Num_Resources <= 0 then
         raise No_Resources_Exception with "Number of resources must be positive";
      end if;
      
      if Total_Resources'Length /= Num_Resources then
         raise Index_Out_Of_Range with "Total_Resources length mismatch";
      end if;

      return State : System_State (Num_Processes, Num_Resources) do
         --  Initialize available resources
         State.Available := Total_Resources;
         
         --  Initialize allocation and max need to zero
         State.Allocation := (others => (others => 0));
         State.Max_Need := (others => (others => 0));
      end return;
   end Initialize_System;

   --  Calculate the Need matrix (Max_Need - Allocation)
   function Calculate_Need (State : System_State) return Resource_Matrix is
      Need : Resource_Matrix (State.Allocation'Range(1), State.Allocation'Range(2));
   begin
      for P in State.Allocation'Range(1) loop
         for R in State.Allocation'Range(2) loop
            Need(P, R) := State.Max_Need(P, R) - State.Allocation(P, R);
         end loop;
      end loop;
      return Need;
   end Calculate_Need;

   --  ====================================================================
   --  SAFETY CHECK ALGORITHM (Core of Banker's Algorithm)
   --  ====================================================================

   --  Check if the current system state is safe
   function Is_Safe (State : System_State) return Safety_Result is
      --  Make copies to work with
      Available_Copy : Resource_Vector (State.Available'Range) := State.Available;
      Finished : array (State.Allocation'Range(1)) of Boolean := (others => False);
      
      --  Need matrix
      Need : Resource_Matrix (State.Allocation'Range(1), State.Allocation'Range(2)) := Calculate_Need(State);
      
      --  Count of processes that haven't finished
      Count : Integer := State.Allocation'Length(1);
      
      --  Flag to track if we made progress in an iteration
      Found : Boolean;
   begin
      --  Main loop: try to find processes that can finish
      loop
         Found := False;
         
         --  Check each process that hasn't finished yet
         for P in State.Allocation'Range(1) loop
            if not Finished(P) then
               --  Check if this process's need can be satisfied with available resources
               if Need(P) <= Available_Copy then
                  --  Process can finish: add its allocated resources to available
                  Available_Copy := Available_Copy + State.Allocation(P);
                  Finished(P) := True;
                  Count := Count - 1;
                  Found := True;
               end if;
            end if;
         end loop;
         
         --  If no process can finish and some haven't finished, state is unsafe
         exit when not Found;
      end loop;
      
      --  If all processes finished, state is safe
      if Count = 0 then
         return Safe;
      else
         return Unsafe;
      end if;
   end Is_Safe;

   --  Find a safe sequence of process execution
   function Find_Safe_Sequence (
      State    : System_State;
      Sequence : out Process_Sequence) 
      return Boolean is
      
      --  Make copies to work with
      Available_Copy : Resource_Vector (State.Available'Range) := State.Available;
      Finished : array (State.Allocation'Range(1)) of Boolean := (others => False);
      Need : Resource_Matrix (State.Allocation'Range(1), State.Allocation'Range(2)) := Calculate_Need(State);
      
      Count : Integer := State.Allocation'Length(1);
      Found : Boolean;
      
      --  Temporary sequence to build up
      Temp_Sequence : Process_Sequence (1 .. State.Allocation'Length(1));
      Temp_Index : Positive := 1;
   begin
      loop
         Found := False;
         
         for P in State.Allocation'Range(1) loop
            if not Finished(P) then
               if Need(P) <= Available_Copy then
                  --  Process can finish
                  Temp_Sequence(Temp_Index) := P;
                  Temp_Index := Temp_Index + 1;
                  Available_Copy := Available_Copy + State.Allocation(P);
                  Finished(P) := True;
                  Count := Count - 1;
                  Found := True;
               end if;
            end if;
         end loop;
         
         exit when not Found;
      end loop;
      
      --  If all processes finished, copy the sequence
      if Count = 0 then
         Sequence := Temp_Sequence(1 .. Temp_Index - 1);
         return True;
      else
         return False;
      end if;
   end Find_Safe_Sequence;

   --  ====================================================================
   --  RESOURCE REQUEST HANDLING
   --  ====================================================================

   --  Check if a request is valid
   function Is_Request_Valid (
      State   : System_State;
      Request : Resource_Request) 
      return Boolean is
      
      Need : Resource_Matrix := Calculate_Need(State);
   begin
      --  Check process index is valid
      if Request.Process < State.Allocation'First(1) or 
         Request.Process > State.Allocation'Last(1) then
         return False;
      end if;
      
      --  Check request doesn't exceed need
      if Request.Resources > Need(Request.Process) then
         return False;
      end if;
      
      --  Check request doesn't exceed available
      if Request.Resources > State.Available then
         return False;
      end if;
      
      return True;
   end Is_Request_Valid;

   --  Check if state is valid
   function Is_State_Valid (State : System_State) return Boolean is
      Total_Allocated : Resource_Vector (State.Available'Range) := (others => 0);
   begin
      --  Check all allocations are <= max needs
      for P in State.Allocation'Range(1) loop
         for R in State.Allocation'Range(2) loop
            if State.Allocation(P, R) > State.Max_Need(P, R) then
               return False;
            end if;
         end loop;
      end loop;
      
      --  Calculate total allocated
      for P in State.Allocation'Range(1) loop
         for R in State.Allocation'Range(2) loop
            Total_Allocated(R) := Total_Allocated(R) + State.Allocation(P, R);
         end loop;
      end loop;
      
      --  Check available is non-negative
      for R in State.Available'Range loop
         if State.Available(R) < 0 then
            return False;
         end if;
      end loop;
      
      return True;
   end Is_State_Valid;

   --  Get total resources in the system
   function Get_Total_Resources (State : System_State) return Resource_Vector is
      Total : Resource_Vector (State.Available'Range) := State.Available;
   begin
      for P in State.Allocation'Range(1) loop
         for R in State.Allocation'Range(2) loop
            Total(R) := Total(R) + State.Allocation(P, R);
         end loop;
      end loop;
      return Total;
   end Get_Total_Resources;

   --  Get the need for a specific process
   function Get_Process_Need (
      State   : System_State;
      Process : Process_Index) 
      return Resource_Vector is
      
      Need : Resource_Vector (State.Max_Need'Range(2));
   begin
      if Process < State.Max_Need'First(1) or Process > State.Max_Need'Last(1) then
         raise Index_Out_Of_Range with "Process ID out of range";
      end if;
      
      for R in State.Max_Need'Range(2) loop
         Need(R) := State.Max_Need(Process, R) - State.Allocation(Process, R);
      end loop;
      return Need;
   end Get_Process_Need;

   --  Check if a process can finish with current allocation
   function Can_Process_Finish (
      State   : System_State;
      Process : Process_Index) 
      return Boolean is
      
      Need : Resource_Vector := Get_Process_Need(State, Process);
   begin
      return Need <= State.Available;
   end Can_Process_Finish;

   --  Handle a resource request using the basic (non-preemptive) Banker's Algorithm
   function Handle_Request_Non_Preemptive (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
      
      --  Create a temporary state to test the request
      Temp_State : System_State := State;
   begin
      --  Validate request
      if Request.Process < Temp_State.Allocation'First(1) or 
         Request.Process > Temp_State.Allocation'Last(1) then
         raise Index_Out_Of_Range with "Invalid process ID in request";
      end if;
      
      if Request.Resources'Length /= Temp_State.Available'Length then
         raise Index_Out_Of_Range with "Resource vector length mismatch";
      end if;
      
      --  Check if request exceeds available
      if Request.Resources > Temp_State.Available then
         raise Request_Exceeds_Available with "Request exceeds available resources";
      end if;
      
      --  Check if request exceeds need
      declare
         Need : Resource_Vector := Get_Process_Need(Temp_State, Request.Process);
      begin
         if Request.Resources > Need then
            raise Max_Exceeded_Exception with "Request exceeds process need";
         end if;
      end;
      
      --  Temporarily grant the request
      Temp_State.Available := Temp_State.Available - Request.Resources;
      Temp_State.Allocation(Request.Process) := Temp_State.Allocation(Request.Process) + Request.Resources;
      
      --  Check if the new state is safe
      if Is_Safe(Temp_State) = Safe then
         --  Request is safe, apply it to the actual state
         State := Temp_State;
         return True;
      else
         --  Request would lead to unsafe state
         raise Unsafe_State_Exception with "Granting request would lead to unsafe state";
      end if;
   exception
      when others =>
         return False;
   end Handle_Request_Non_Preemptive;

   --  ====================================================================
   --  PREEMPTIVE VARIANT
   --  ====================================================================

   --  Handle a resource request using the preemptive variant
   function Handle_Request_Preemptive (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
      
      Temp_State : System_State := State;
      Need : Resource_Vector := Get_Process_Need(Temp_State, Request.Process);
      
      --  Total resources in the system
      Total_Resources : Resource_Vector := Get_Total_Resources(Temp_State);
   begin
      --  Validate request
      if Request.Process < Temp_State.Allocation'First(1) or 
         Request.Process > Temp_State.Allocation'Last(1) then
         raise Index_Out_Of_Range with "Invalid process ID in request";
      end if;
      
      if Request.Resources'Length /= Temp_State.Available'Length then
         raise Index_Out_Of_Range with "Resource vector length mismatch";
      end if;
      
      --  Check if request exceeds need
      if Request.Resources > Need then
         raise Max_Exceeded_Exception with "Request exceeds process need";
      end if;
      
      --  Check if request exceeds total system resources
      if Request.Resources > Total_Resources then
         raise Request_Exceeds_Available with "Request exceeds total system resources";
      end if;
      
      --  If request can be satisfied with available resources, try non-preemptive first
      if Request.Resources <= Temp_State.Available then
         Temp_State.Available := Temp_State.Available - Request.Resources;
         Temp_State.Allocation(Request.Process) := Temp_State.Allocation(Request.Process) + Request.Resources;
         
         if Is_Safe(Temp_State) = Safe then
            State := Temp_State;
            return True;
         end if;
      end if;
      
      --  Preemptive approach: try to take resources from other processes
      declare
         Required : Resource_Vector := Request.Resources - Temp_State.Available;
         Preempt_Amount : Resource_Vector (Temp_State.Available'Range) := (others => 0);
      begin
         --  Calculate how much we need to preempt
         for R in Required'Range loop
            if Required(R) > 0 then
               Preempt_Amount(R) := Required(R);
            end if;
         end loop;
         
         --  If no preemption needed, we already tried that above
         if Preempt_Amount = (others => 0) then
            raise Unsafe_State_Exception with "Cannot satisfy request even with preemption";
         end if;
         
         --  Try to find processes to preempt
         for P in Temp_State.Allocation'Range(1) loop
            if P = Request.Process then
               null;
            else
               for R in Preempt_Amount'Range loop
                  if Preempt_Amount(R) > 0 and Temp_State.Allocation(P, R) > 0 then
                     declare
                        Take : Resource_Count := Integer'Min(Preempt_Amount(R), Temp_State.Allocation(P, R));
                     begin
                        Preempt_Amount(R) := Preempt_Amount(R) - Take;
                        Temp_State.Allocation(P, R) := Temp_State.Allocation(P, R) - Take;
                        Temp_State.Available(R) := Temp_State.Available(R) + Take;
                     end;
                  end if;
               end loop;
               
               exit when Preempt_Amount = (others => 0);
            end if;
         end loop;
         
         --  If we still need to preempt, try more aggressive approach
         if Preempt_Amount /= (others => 0) then
            for P in Temp_State.Allocation'Range(1) loop
               if P = Request.Process then
                  null;
               else
                  for R in Preempt_Amount'Range loop
                     if Preempt_Amount(R) > 0 and Temp_State.Allocation(P, R) > 0 then
                        declare
                           Take : Resource_Count := Integer'Min(Preempt_Amount(R), Temp_State.Allocation(P, R));
                        begin
                           Preempt_Amount(R) := Preempt_Amount(R) - Take;
                           Temp_State.Allocation(P, R) := Temp_State.Allocation(P, R) - Take;
                           Temp_State.Available(R) := Temp_State.Available(R) + Take;
                        end;
                     end if;
                  end loop;
                  
                  exit when Preempt_Amount = (others => 0);
               end if;
            end loop;
         end if;
         
         --  If we still can't satisfy the request, fail
         if Preempt_Amount /= (others => 0) then
            raise Unsafe_State_Exception with "Cannot satisfy request even with full preemption";
         end if;
         
         --  Now try to grant the request
         Temp_State.Available := Temp_State.Available - Request.Resources;
         Temp_State.Allocation(Request.Process) := Temp_State.Allocation(Request.Process) + Request.Resources;
         
         --  Check if the new state is safe
         if Is_Safe(Temp_State) = Safe then
            State := Temp_State;
            return True;
         else
            raise Unsafe_State_Exception with "Granting request would lead to unsafe state even after preemption";
         end if;
      end;
   exception
      when others =>
         return False;
   end Handle_Request_Preemptive;

   --  ====================================================================
   --  STATIC VARIANT
   --  ====================================================================

   --  Initialize a static system
   function Initialize_Static_System (
      Num_Processes  : Process_Index;
      Num_Resources  : Resource_Index;
      Total_Resources : Resource_Vector;
      Max_Needs      : Resource_Matrix) 
      return System_State is
      
      State : System_State := Initialize_System(Num_Processes, Num_Resources, Total_Resources);
   begin
      --  Validate Max_Needs dimensions
      if Max_Needs'Length(1) /= Num_Processes or Max_Needs'Length(2) /= Num_Resources then
         raise Index_Out_Of_Range with "Max_Needs dimensions don't match system";
      end if;
      
      --  Set max needs
      State.Max_Need := Max_Needs;
      
      return State;
   end Initialize_Static_System;

   --  Handle request in static system
   function Handle_Static_Request (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
   begin
      return Handle_Request_Non_Preemptive(State, Request);
   end Handle_Static_Request;

   --  ====================================================================
   --  DYNAMIC VARIANT
   --  ====================================================================

   --  Add a new process to the system
   function Add_Process (
      State            : in out System_State;
      Max_Need         : Resource_Vector;
      Initial_Allocation : Resource_Vector) 
      return Process_Index is
      
      New_Num_Processes : Process_Index := State.Num_Processes + 1;
      New_State : System_State (New_Num_Processes, State.Num_Resources);
   begin
      --  Validate input
      if Max_Need'Length /= State.Num_Resources or Initial_Allocation'Length /= State.Num_Resources then
         raise Index_Out_Of_Range with "Vector length mismatch with system resources";
      end if;
      
      --  Check if initial allocation exceeds max need
      if Initial_Allocation > Max_Need then
         raise Max_Exceeded_Exception with "Initial allocation exceeds max need";
      end if;
      
      --  Check if we have enough resources for initial allocation
      if Initial_Allocation > State.Available then
         raise No_Resources_Exception with "Not enough resources for initial allocation";
      end if;
      
      --  Copy existing state
      New_State.Available := State.Available - Initial_Allocation;
      New_State.Allocation(1 .. State.Num_Processes, 1 .. State.Num_Resources) := State.Allocation;
      New_State.Max_Need(1 .. State.Num_Processes, 1 .. State.Num_Resources) := State.Max_Need;
      
      --  Add new process
      New_State.Allocation(New_Num_Processes, 1 .. State.Num_Resources) := Initial_Allocation;
      New_State.Max_Need(New_Num_Processes, 1 .. State.Num_Resources) := Max_Need;
      
      --  Check if the new state is safe
      if Is_Safe(New_State) = Safe then
         State := New_State;
         return New_Num_Processes;
      else
         raise Unsafe_State_Exception with "Adding process would lead to unsafe state";
      end if;
   end Add_Process;

   --  Remove a process from the system
   function Remove_Process (
      State   : in out System_State;
      Process : Process_Index) 
      return Resource_Vector is
      
      New_Num_Processes : Process_Index := State.Num_Processes - 1;
      New_State : System_State (New_Num_Processes, State.Num_Resources);
      Returned_Resources : Resource_Vector (1 .. State.Num_Resources);
   begin
      --  Validate process ID
      if Process < 1 or Process > State.Num_Processes then
         raise Index_Out_Of_Range with "Invalid process ID";
      end if;
      
      --  Get the resources to return
      Returned_Resources := State.Allocation(Process);
      
      --  Copy state, skipping the removed process
      New_State.Available := State.Available + Returned_Resources;
      
      declare
         New_Index : Process_Index := 1;
      begin
         for Old_Index in 1 .. State.Num_Processes loop
            if Old_Index /= Process then
               New_State.Allocation(New_Index) := State.Allocation(Old_Index);
               New_State.Max_Need(New_Index) := State.Max_Need(Old_Index);
               New_Index := New_Index + 1;
            end if;
         end loop;
      end;
      
      State := New_State;
      return Returned_Resources;
   end Remove_Process;

   --  Handle request in dynamic system
   function Handle_Dynamic_Request (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
   begin
      return Handle_Request_Non_Preemptive(State, Request);
   end Handle_Dynamic_Request;

   --  ====================================================================
   --  ALGORITHM SELECTOR
   --  ====================================================================

   --  Handle a request using the specified algorithm variant
   function Handle_Request (
      State   : in out System_State;
      Request : Resource_Request;
      Variant : Algorithm_Variant := Non_Preemptive) 
      return Boolean is
   begin
      case Variant is
         when Non_Preemptive =>
            return Handle_Request_Non_Preemptive(State, Request);
         when Preemptive =>
            return Handle_Request_Preemptive(State, Request);
         when Static =>
            return Handle_Static_Request(State, Request);
         when Dynamic =>
            return Handle_Dynamic_Request(State, Request);
      end case;
   end Handle_Request;

end Bankers_Algorithm;
