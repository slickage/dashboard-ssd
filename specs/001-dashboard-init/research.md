# Research for Slickage Dashboard MVP

This document outlines the research needed to clarify open questions before starting the design and implementation phases.

## Performance Goals

- **Task**: Define specific performance goals for the application.
- **Answer**: Performance is not a primary focus for the initial version.

## Constraints

- **Task**: Identify any specific constraints for the project.
- **Questions**:
    - Are there any budget or timeline constraints?
    - Are there any technology constraints not already identified?

## Scale/Scope

- **Task**: Define the expected scale and scope of the application.
- **Answer**: The application will have a small user base initially, but it should be able to support a low or high number of projects.

## Architecture

- **Task**: Clarify the architectural approach for a "library-first" design in Phoenix.
- **Questions**:
    - How should Phoenix contexts be used to align with the "library-first" principle?
    - Should some core functionalities be implemented as separate Hex packages?