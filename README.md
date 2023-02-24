# bancey-infra

## Self Hosted Agents

docker run -e AZP_URL="https://dev.azure.com/bancey" -e AZP_TOKEN="<PAT TOKEN>" -e AZP_AGENT_NAME="dockeragent0" -e AZP_POOL="Local" bancey/ado-agent:latest
