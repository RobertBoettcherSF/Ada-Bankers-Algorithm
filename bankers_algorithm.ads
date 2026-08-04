--  bankers_algorithm.ads
--  
--  Ada implementation of the Banker's Algorithm for deadlock avoidance
--  Based on: https://en.wikipedia.org/wiki/Banker's_algorithm
--  
--  This package provides a complete implementation of the Banker's Algorithm
--  including all variants mentioned in the Wikipedia article:
--  - Basic (non-preemptive) Banker's Algorithm
--  - Preemptive variant (with resource reclamation)
--  - Static variant (fixed number of processes)
--  - Dynamic variant (processes can enter/leave system)
--  
--  Author: Vibe Code (Mistral AI)
--  Date: 2024

with Ada.Containers.Vectors;

package Bankers_Algorithm is

   --  ====================================================================
   --  EXCEPTIONS
   --  ====================================================================

   --  Exception raised when a resource request cannot be satisfied
   --  (not enough resources available)
   Request_Exceeds_Available : exception;

   --  Exception raised when a request would lead to an unsafe state
   Unsafe_State_Exception : exception;

   --  Exception raised when trying to allocate more than maximum declared
   Max_Exceeded_Exception : exception;

   --  Exception raised for invalid indices (process or resource out of range)
   Index_Out_Of_Range : exception;

   --  Exception raised when system has no resources
   No_Resources_Exception : exception;

   --  Exception raised when no processes exist
   No_Processes_Exception : exception;

   --  ====================================================================
   --  TYPES
   --  ====================================================================

   --  Type for resource counts (non-negative integers)
   type Resource_Count is range 0 .. Integer'Last;

   --  Type for process and resource indices
   type Index_Type is range 1 .. Integer'Last;

   --  Type for process IDs
   type Process_ID is range 1 .. Integer'Last;

   --  Type for resource types
   type Resource_Type is range 1 .. Integer'Last;

   --  Vector type for available resources
   type Resource_Vector is array (Resource_Type range <>) of Resource_Count;

   --  Matrix type for allocation and maximum needs
   type Resource_Matrix is array (Process_ID range <>, Resource_Type range <>) of Resource_Count;

   --  Type to represent the system state
   type System_State (Num_Processes : Process_ID; Num_Resources : Resource_Type) is
      record
         Available   : Resource_Vector (1 .. Num_Resources);
         Allocation  : Resource_Matrix (1 .. Num_Processes, 1 .. Num_Resources);
         Max_Need    : Resource_Matrix (1 .. Num_Processes, 1 .. Num_Resources);
      end record;

   --  Type to represent a resource request
   type Resource_Request (Num_Resources : Resource_Type) is
      record
         Process    : Process_ID;
         Resources  : Resource_Vector (1 .. Num_Resources);
      end record;

   --  Type to represent the result of a safety check
   type Safety_Result is (Safe, Unsafe);

   --  Type for algorithm variant selection
   type Algorithm_Variant is (Non_Preemptive, Preemptive, Static, Dynamic);

   --  ====================================================================
   --  BASIC OPERATIONS
   --  ====================================================================

   --  Initialize a system state with given parameters
   --  Parameters:
   --    Num_Processes  - Number of processes in the system
   --    Num_Resources  - Number of resource types
   --    Total_Resources - Total amount of each resource in the system
   --  Returns: Initialized system state with all allocations set to zero
   function Initialize_System (
      Num_Processes  : Process_ID;
      Num_Resources  : Resource_Type;
      Total_Resources : Resource_Vector)
      return System_State;

   --  Calculate the Need matrix (Max_Need - Allocation)
   --  Parameters:
   --    State - The system state
   --  Returns: The Need matrix
   function Calculate_Need (State : System_State) return Resource_Matrix;

   --  ====================================================================
   --  SAFETY CHECK ALGORITHM
   --  ====================================================================

   --  Check if the current system state is safe
   --  This is the core of the Banker's Algorithm
   --  Parameters:
   --    State - The system state to check
   --  Returns: Safe if a safe sequence exists, Unsafe otherwise
   function Is_Safe (State : System_State) return Safety_Result;

   --  Find a safe sequence of process execution
   --  Parameters:
   --    State    - The system state
   --    Sequence - Output parameter: array of process IDs in safe order
   --  Returns: True if safe sequence exists, False otherwise
   function Find_Safe_Sequence (
      State    : System_State;
      Sequence : out Ada.Containers.Vectors.Vector) 
      return Boolean;

   --  ====================================================================
   --  RESOURCE REQUEST HANDLING
   --  ====================================================================

   --  Handle a resource request using the basic (non-preemptive) Banker's Algorithm
   --  Parameters:
   --    State   - Current system state (in out, modified if request is granted)
   --    Request - The resource request to handle
   --  Returns: True if request was granted, False otherwise
   --  Raises: Request_Exceeds_Available if request > available
   --          Unsafe_State_Exception if granting would lead to unsafe state
   --          Max_Exceeded_Exception if request > remaining need
   function Handle_Request_Non_Preemptive (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean;

   --  Handle a resource request using the preemptive variant
   --  In preemptive mode, resources can be taken back from other processes
   --  to satisfy the request if it would lead to a safe state
   --  Parameters:
   --    State   - Current system state (in out, modified if request is granted)
   --    Request - The resource request to handle
   --  Returns: True if request was granted, False otherwise
   --  Raises: Request_Exceeds_Available if request > total system resources
   --          Max_Exceeded_Exception if request > remaining need
   function Handle_Request_Preemptive (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean;

   --  ====================================================================
   --  STATIC VARIANT (Fixed number of processes)
   --  ====================================================================

   --  Initialize a static system (fixed number of processes)
   --  Parameters:
   --    Num_Processes  - Fixed number of processes
   --    Num_Resources  - Number of resource types
   --    Total_Resources - Total amount of each resource
   --    Max_Needs      - Maximum needs for each process
   --  Returns: Initialized static system state
   function Initialize_Static_System (
      Num_Processes  : Process_ID;
      Num_Resources  : Resource_Type;
      Total_Resources : Resource_Vector;
      Max_Needs      : Resource_Matrix) 
      return System_State;

   --  Handle request in static system (no process addition/removal)
   function Handle_Static_Request (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean;

   --  ====================================================================
   --  DYNAMIC VARIANT (Processes can enter/leave)
   --  ====================================================================

   --  Add a new process to the system (dynamic variant)
   --  Parameters:
   --    State      - Current system state (in out, resized)
   --    Max_Need   - Maximum resource needs for the new process
   --    Initial_Allocation - Initial resources to allocate to the new process
   --  Returns: New process ID
   --  Raises: No_Resources_Exception if not enough resources for initial allocation
   --          Unsafe_State_Exception if adding process would make system unsafe
   function Add_Process (
      State            : in out System_State;
      Max_Need         : Resource_Vector;
      Initial_Allocation : Resource_Vector) 
      return Process_ID;

   --  Remove a process from the system (dynamic variant)
   --  Parameters:
   --    State   - Current system state (in out, resized)
   --    Process - Process ID to remove
   --  Returns: Resources that were allocated to the removed process
   function Remove_Process (
      State   : in out System_State;
      Process : Process_ID) 
      return Resource_Vector;

   --  Handle request in dynamic system (processes can be added/removed)
   function Handle_Dynamic_Request (
      State   : in out System_State;
      Request : Resource_Request) 
      return Boolean;

   --  ====================================================================
   --  UTILITY FUNCTIONS
   --  ====================================================================

   --  Check if a request is valid (doesn't exceed need or available)
   --  Parameters:
   --    State   - Current system state
   --    Request - The request to validate
   --  Returns: True if request is valid, False otherwise
   function Is_Request_Valid (
      State   : System_State;
      Request : Resource_Request) 
      return Boolean;

   --  Check if a state is valid (all allocations <= max, sum(allocation) <= available + sum(allocation))
   --  Parameters:
   --    State - The system state to validate
   --  Returns: True if state is valid, False otherwise
   function Is_State_Valid (State : System_State) return Boolean;

   --  Get the total resources in the system
   --  Parameters:
   --    State - The system state
   --  Returns: Total resources (available + allocated)
   function Get_Total_Resources (State : System_State) return Resource_Vector;

   --  Get the need for a specific process
   --  Parameters:
   --    State   - The system state
   --    Process - Process ID
   --  Returns: Need vector for the process
   function Get_Process_Need (
      State   : System_State;
      Process : Process_ID) 
      return Resource_Vector;

   --  Check if a process can finish with current allocation
   --  Parameters:
   --    State   - The system state
   --    Process - Process ID
   --  Returns: True if process can finish (need <= available), False otherwise
   function Can_Process_Finish (
      State   : System_State;
      Process : Process_ID) 
      return Boolean;

   --  ====================================================================
   --  ALGORITHM SELECTOR
   --  ====================================================================

   --  Handle a request using the specified algorithm variant
   --  Parameters:
   --    State    - Current system state
   --    Request  - The resource request
   --    Variant  - Which algorithm variant to use
   --  Returns: True if request was granted, False otherwise
   function Handle_Request (
      State   : in out System_State;
      Request : Resource_Request;
      Variant : Algorithm_Variant := Non_Preemptive) 
      return Boolean;

end Bankers_Algorithm;
