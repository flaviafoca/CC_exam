# CC_exam
#### Erlang-Based Research Management System ####

#### Overview ####
This project implements a simple research management system in Erlang, developed for the Cloud Computing exam.
The application follows a client-server architecture and uses Erlang processes, message passing, pattern matching, and DETS persistent storage to manage research projects, researchers, participations, and tasks.
The system also supports communication between distributed Erlang nodes.

#### Requirements ####
- Erlang/OTP 29 (version used for development and testing).

## Compilation and Execution
Open an Erlang shell in the project directory and compile the source file:

c(research).

Start the server:

ServerPid = research:start().

Example of a project retrieval request:

research:request_get_project(ServerPid, 1).

Stop the server:

ServerPid ! stop.

#### Data Storage ####
The application uses four DETS tables: `progetti`, `ricercatori`, `partecipazioni`, and `tasks`.

DETS files are opened or created when the server starts. The database structure and the records used during testing are documented in Appendix A of the accompanying report.

#### Documentation ####
The PDF report provides a description of the system architecture, implementation, validation procedures, and distributed testing.
