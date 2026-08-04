--  bankers_algorithm.adb
--  
--  Ada implementation of the Banker's Algorithm
--  Based on: https://en.wikipedia.org/wiki/Banker's_algorithm
--  
--  Author: Vibe Code (Mistral AI)
--  Date: 2024

package body Bankers_Algorithm is

   --  ====================================================================
   --  HELPER FUNCTIONS

   --  Helper function to get a row from a resource matrix
   function Get_Row (Matrix : Resource_Matrix; Row : Positive) return Resource_Vector is
      Result : Resource_Vector (Matrix'Range(2));
   begin
      for R in Matrix'Range(2) loop
         Result(R) := Matrix(Row, R);
      end loop;
      return Result;
   end Get_Row;

   --  ====================================================================

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

   function "+" (Left, Right : Resource_Vector) return Resource_Vector is
      Result : Resource_Vector (Left'Range);
   begin
      for I in Left'Range loop
         Result(I) := Left(I) + Right(I);
      end loop;
      return Result;
   end "+";

   function "-" (Left, Right : Resource_Vector) return Resource_Vector is
      Result : Resource_Vector (Left'Range);
   begin
      for I in Left'Range loop
         Result(I) := Left(I) - Right(I);
      end loop;
      return Result;
   end "-";


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  BASIC OPERATIONS

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

   function Initialize_System (
      Num_Processes  : Positive;
      Num_Resources  : Positive;
      Total_Resources : Resource_Vector)
      return System_State is
   begin
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
         State.Available := Total_Resources;
         State.Allocation := (others => (others => 0));
         State.Max_Need := (others => (others => 0));
      end return;
   end Initialize_System;

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


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  SAFETY CHECK ALGORITHM

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

   function Is_Safe (State : System_State) return Safety_Result is
      Available_Copy : Resource_Vector (State.Available'Range) := State.Available;
      Finished : array (State.Allocation'Range(1)) of Boolean := (others => False);
      Need : Resource_Matrix (State.Allocation'Range(1), State.Allocation'Range(2)) := Calculate_Need(State);
      Count : Integer := State.Allocation'Length(1);
      Found : Boolean;
   begin
      loop
         Found := False;
         for P in State.Allocation'Range(1) loop
            if not Finished(P) then
               if Get_Row(Need, P) <= Available_Copy then
                  Available_Copy := Available_Copy + Get_Row(State.Allocation, P);
                  Finished(P) := True;
                  Count := Count - 1;
                  Found := True;
               end if;
            end if;
         end loop;
         exit when not Found;
      end loop;
      if Count = 0 then
         return Safe;
      else
         return Unsafe;
      end if;
   end Is_Safe;

   function Find_Safe_Sequence (
      State    : System_State;
      Sequence : out Process_Sequence) 
      return Boolean is
      Available_Copy : Resource_Vector (State.Available'Range) := State.Available;
      Finished : array (State.Allocation'Range(1)) of Boolean := (others => False);
      Need : Resource_Matrix (State.Allocation'Range(1), State.Allocation'Range(2)) := Calculate_Need(State);
      Count : Integer := State.Allocation'Length(1);
      Found : Boolean;
      Temp_Sequence : Process_Sequence (1 .. State.Allocation'Length(1));
      Temp_Index : Positive := 1;
   begin
      loop
         Found := False;
         for P in State.Allocation'Range(1) loop
            if not Finished(P) then
               if Get_Row(Need, P) <= Available_Copy then
                  Temp_Sequence(Temp_Index) := P;
                  Temp_Index := Temp_Index + 1;
                  Available_Copy := Available_Copy + Get_Row(State.Allocation, P);
                  Finished(P) := True;
                  Count := Count - 1;
                  Found := True;
               end if;
            end if;
         end loop;
         exit when not Found;
      end loop;
      if Count = 0 then
         Sequence := Temp_Sequence(1 .. Temp_Index - 1);
         return True;
      else
         return False;
      end if;
   end Find_Safe_Sequence;


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  RESOURCE REQUEST HANDLING

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

   function Is_Request_Valid (
      State   : System_State;
      Request : Resource_Request) 
      return Boolean is
      Need : Resource_Matrix := Calculate_Need(State);
   begin
      if Request.Process < State.Allocation'First(1) or Request.Process > State.Allocation'Last(1) then
         return False;
      end if;
      if Request.Resources > Need(Request.Process) then
         return False;
      end if;
      if Request.Resources > State.Available then
         return False;
      end if;
      return True;
   end Is_Request_Valid;

   function Is_State_Valid (State : System_State) return Boolean is
      Total_Allocated : Resource_Vector (State.Available'Range) := (others => 0);
   begin
      for P in State.Allocation'Range(1) loop
         for R in State.Allocation'Range(2) loop
            if State.Allocation(P, R) > State.Max_Need(P, R) then
               return False;
            end if;
         end loop;
      end loop;
      for P in State.Allocation'Range(1) loop
         for R in State.Allocation'Range(2) loop
            Total_Allocated(R) := Total_Allocated(R) + State.Allocation(P, R);
         end loop;
      end loop;
      for R in State.Available'Range loop
         if State.Available(R) < 0 then
            return False;
         end if;
      end loop;
      return True;
   end Is_State_Valid;

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

   function Get_Process_Need (
      State   : System_State;
      Process : Positive) 
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

   function Can_Process_Finish (
      State   : System_State;
      Process : Positive) 
      return Boolean is
      Need : Resource_Vector := Get_Process_Need(State, Process);
   begin
      return Need <= State.Available;
   end Can_Process_Finish;

   function Handle_Request_Non_Preemptive (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
      Temp_State : System_State := State;
   begin
      if Request.Process < Temp_State.Allocation'First(1) or Request.Process > Temp_State.Allocation'Last(1) then
         raise Index_Out_Of_Range with "Invalid process ID in request";
      end if;
      if Request.Resources'Length /= Temp_State.Available'Length then
         raise Index_Out_Of_Range with "Resource vector length mismatch";
      end if;
      if Request.Resources > Temp_State.Available then
         raise Request_Exceeds_Available with "Request exceeds available resources";
      end if;
      declare
         Need : Resource_Vector := Get_Process_Need(Temp_State, Request.Process);
      begin
         if Request.Resources > Need then
            raise Max_Exceeded_Exception with "Request exceeds process need";
         end if;
      end;
      Temp_State.Available := Temp_State.Available - Request.Resources;
      for R in Temp_State.Available'Range loop
         Temp_State.Allocation(Request.Process, R) := Temp_State.Allocation(Request.Process, R) + Request.Resources(R);
      end loop;
      if Is_Safe(Temp_State) = Safe then
         State := Temp_State;
         return True;
      else
         raise Unsafe_State_Exception with "Granting request would lead to unsafe state";
      end if;
   exception
      when others =>
         return False;
   end Handle_Request_Non_Preemptive;


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  PREEMPTIVE VARIANT

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

   function Handle_Request_Preemptive (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
      Temp_State : System_State := State;
      Need : Resource_Vector := Get_Process_Need(Temp_State, Request.Process);
      Total_Resources : Resource_Vector := Get_Total_Resources(Temp_State);
   begin
      if Request.Process < Temp_State.Allocation'First(1) or Request.Process > Temp_State.Allocation'Last(1) then
         raise Index_Out_Of_Range with "Invalid process ID in request";
      end if;
      if Request.Resources'Length /= Temp_State.Available'Length then
         raise Index_Out_Of_Range with "Resource vector length mismatch";
      end if;
      if Request.Resources > Need then
         raise Max_Exceeded_Exception with "Request exceeds process need";
      end if;
      if Request.Resources > Total_Resources then
         raise Request_Exceeds_Available with "Request exceeds total system resources";
      end if;
      if Request.Resources <= Temp_State.Available then
         Temp_State.Available := Temp_State.Available - Request.Resources;
         for R in Temp_State.Available'Range loop
            Temp_State.Allocation(Request.Process, R) := Temp_State.Allocation(Request.Process, R) + Request.Resources(R);
         end loop;
         if Is_Safe(Temp_State) = Safe then
            State := Temp_State;
            return True;
         end if;
      end if;
      declare
         Required : Resource_Vector := Request.Resources - Temp_State.Available;
         Preempt_Amount : Resource_Vector (Temp_State.Available'Range) := (others => 0);
      begin
         for R in Required'Range loop
            if Required(R) > 0 then
               Preempt_Amount(R) := Required(R);
            end if;
         end loop;
         if Preempt_Amount = (others => 0) then
            raise Unsafe_State_Exception with "Cannot satisfy request even with preemption";
         end if;
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
         if Preempt_Amount /= (others => 0) then
            raise Unsafe_State_Exception with "Cannot satisfy request even with full preemption";
         end if;
         Temp_State.Available := Temp_State.Available - Request.Resources;
         for R in Temp_State.Available'Range loop
            Temp_State.Allocation(Request.Process, R) := Temp_State.Allocation(Request.Process, R) + Request.Resources(R);
         end loop;
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


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  STATIC VARIANT

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

   function Initialize_Static_System (
      Num_Processes  : Positive;
      Num_Resources  : Positive;
      Total_Resources : Resource_Vector;
      Max_Needs      : Resource_Matrix) 
      return System_State is
      State : System_State := Initialize_System(Num_Processes, Num_Resources, Total_Resources);
   begin
      if Max_Needs'Length(1) /= Num_Processes or Max_Needs'Length(2) /= Num_Resources then
         raise Index_Out_Of_Range with "Max_Needs dimensions don't match system";
      end if;
      State.Max_Need := Max_Needs;
      return State;
   end Initialize_Static_System;

   function Handle_Static_Request (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
   begin
      return Handle_Request_Non_Preemptive(State, Request);
   end Handle_Static_Request;


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  DYNAMIC VARIANT

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

   function Add_Process (
      State            : in out System_State;
      Max_Need         : Resource_Vector;
      Initial_Allocation : Resource_Vector) 
      return Positive is
      New_Num_Processes : Positive := State.Num_Processes + 1;
      New_State : System_State (New_Num_Processes, State.Num_Resources);
   begin
      if Max_Need'Length /= State.Num_Resources or Initial_Allocation'Length /= State.Num_Resources then
         raise Index_Out_Of_Range with "Vector length mismatch with system resources";
      end if;
      if Initial_Allocation > Max_Need then
         raise Max_Exceeded_Exception with "Initial allocation exceeds max need";
      end if;
      if Initial_Allocation > State.Available then
         raise No_Resources_Exception with "Not enough resources for initial allocation";
      end if;
      New_State.Available := State.Available - Initial_Allocation;
      --  Copy existing allocations and max needs
      for P in 1 .. State.Num_Processes loop
         for R in 1 .. State.Num_Resources loop
            New_State.Allocation(P, R) := State.Allocation(P, R);
            New_State.Max_Need(P, R) := State.Max_Need(P, R);
         end loop;
      end loop;
      --  Add new process
      for R in 1 .. State.Num_Resources loop
         New_State.Allocation(New_Num_Processes, R) := Initial_Allocation(R);
         New_State.Max_Need(New_Num_Processes, R) := Max_Need(R);
      end loop;
      if Is_Safe(New_State) = Safe then
         State := New_State;
         return New_Num_Processes;
      else
         raise Unsafe_State_Exception with "Adding process would lead to unsafe state";
      end if;
   end Add_Process;

   function Remove_Process (
      State   : in out System_State;
      Process : Positive) 
      return Resource_Vector is
      New_Num_Processes : Positive := State.Num_Processes - 1;
      New_State : System_State (New_Num_Processes, State.Num_Resources);
      Returned_Resources : Resource_Vector (1 .. State.Num_Resources);
   begin
      if Process < 1 or Process > State.Num_Processes then
         raise Index_Out_Of_Range with "Invalid process ID";
      end if;
      for R in State.Available'Range loop
         Returned_Resources(R) := State.Allocation(Process, R);
      end loop;
      New_State.Available := State.Available + Returned_Resources;
      declare
         New_Index : Positive := 1;
      begin
         for Old_Index in 1 .. State.Num_Processes loop
            if Old_Index /= Process then
               for R in State.Available'Range loop
                  New_State.Allocation(New_Index, R) := State.Allocation(Old_Index, R);
               end loop;
               for R in State.Available'Range loop
                  New_State.Max_Need(New_Index, R) := State.Max_Need(Old_Index, R);
               end loop;
               New_Index := New_Index + 1;
            end if;
         end loop;
      end;
      State := New_State;
      return Returned_Resources;
   end Remove_Process;

   function Handle_Dynamic_Request (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean is
   begin
      return Handle_Request_Non_Preemptive(State, Request);
   end Handle_Dynamic_Request;


   --  Helper function to get a row from a resource matrix

   --  ====================================================================
   --  ALGORITHM SELECTOR

   --  Helper function to get a row from a resource matrix

   --  ====================================================================

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
