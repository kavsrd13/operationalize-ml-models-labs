"""Local Streamlit chat for the latest Foundry agent version."""
import streamlit as st

from agent_common import AGENT_NAME, project_client

st.set_page_config(page_title="Olist data analyst", page_icon="📊", layout="wide")
st.title("📊 Olist data analyst")
st.caption("Foundry prompt agent + Code Interpreter · 300-order teaching sample")

if "messages" not in st.session_state:
    st.session_state.messages = []
if st.button("New conversation"):
    st.session_state.pop("conversation_id", None)
    st.session_state.messages = []
    st.rerun()

with st.sidebar:
    st.subheader("Try asking")
    st.markdown("- How many orders and order items are in the sample?\n- Which seller states have the highest total item price?\n- Compare average freight value by customer state. State the join keys.")
    st.info("This is a sample, not the full Olist dataset. Each prompt uses the latest registered agent version.")

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

prompt = st.chat_input("Ask a question about the Olist CSV files")
if prompt:
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)
    with st.chat_message("assistant"):
        with st.spinner("Analyzing the CSV files..."):
            with project_client() as project, project.get_openai_client() as openai:
                if "conversation_id" not in st.session_state:
                    st.session_state.conversation_id = openai.conversations.create().id
                response = openai.responses.create(
                    conversation=st.session_state.conversation_id,
                    input=prompt,
                    extra_body={"agent_reference": {"name": AGENT_NAME, "type": "agent_reference"}},
                )
            answer = response.output_text or "The agent returned no text. Check the Foundry run trace."
            st.markdown(answer)
    st.session_state.messages.append({"role": "assistant", "content": answer})
