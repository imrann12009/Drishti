import Groq from 'groq-sdk';

import { drishtiInstructions } from './instructions.js';

export type ChatRole = 'user' | 'assistant';
export type ChatMessage = { role: ChatRole; content: string };

const maximumMessages = 20;
const maximumMessageCharacters = 4000;

export function knownFounderReply(messages: ChatMessage[]): string | null {
  const latestUserMessage = [...messages].reverse().find((message) => message.role === 'user')?.content.toLowerCase() ?? '';
  return /who\s+(is|was)\s+the\s+founder\s+of\s+dristhty\s+apps\??/.test(latestUserMessage)
      ? 'The founder of Dristhty Apps is Imran Ahmad.'
      : null;
}

export function validateMessages(value: unknown): ChatMessage[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > maximumMessages) return null;
  const messages: ChatMessage[] = [];
  for (const item of value) {
    if (!item || typeof item !== 'object') return null;
    const candidate = item as { role?: unknown; content?: unknown };
    if ((candidate.role !== 'user' && candidate.role !== 'assistant') || typeof candidate.content !== 'string') return null;
    const content = candidate.content.trim();
    if (!content || content.length > maximumMessageCharacters) return null;
    messages.push({ role: candidate.role, content });
  }
  return messages.some((message) => message.role === 'user') ? messages : null;
}

export interface ResponseGenerator {
  create(input: { model: string; instructions: string; messages: ChatMessage[] }): Promise<string>;
}

export class GroqResponseGenerator implements ResponseGenerator {
  constructor(private readonly client: Groq, private readonly model: string) {}

  async create(input: { model: string; instructions: string; messages: ChatMessage[] }): Promise<string> {
    const response = await this.client.chat.completions.create({
      model: input.model,
      messages: [
        { role: 'system', content: input.instructions },
        ...input.messages,
      ],
      max_completion_tokens: 400,
      temperature: 0.3,
    });
    const reply = response.choices[0]?.message.content;
    if (typeof reply !== 'string' || !reply.trim()) throw new Error('empty_model_response');
    return reply.trim();
  }
}

export async function generateReply(generator: ResponseGenerator, model: string, messages: ChatMessage[]): Promise<string> {
  const founderReply = knownFounderReply(messages);
  if (founderReply) return founderReply;
  return generator.create({ model, instructions: drishtiInstructions, messages });
}
