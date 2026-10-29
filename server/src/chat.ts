import Groq from 'groq-sdk';

import { drishtiInstructions } from './instructions.js';

export type ChatRole = 'user' | 'assistant';
export type ChatMessage = { role: ChatRole; content: string };

const maximumMessages = 20;
const maximumMessageCharacters = 4000;

export function knownFounderReply(messages: ChatMessage[]): string | null {
  const message = [...messages].reverse().find((entry) => entry.role === 'user')?.content ?? '';
  const latestUserMessage = message.toLowerCase();
  const bangla = /[\u0980-\u09FF]/.test(message);
  const responses = bangla
      ? {
          founder: 'Drishti-এর প্রতিষ্ঠাতা হলেন Imran Ahmad।',
          education: 'Imran Ahmad Gono Bishwabidyalay-এর CSE বিভাগে পড়াশোনা করেন।',
          location: 'Imran Ahmad সাভারে থাকেন।',
          height: 'Imran Ahmad-এর উচ্চতা ৫ ফুট ৫ ইঞ্চি।',
          relationship: 'Imran Ahmad-এর relationship status single।',
          netWorth: 'Imran Ahmad-এর জানানো net worth ০ টাকা।',
          profile: 'Imran Ahmad Gono Bishwabidyalay-এর CSE বিভাগে পড়াশোনা করেন, সাভারে থাকেন, তাঁর উচ্চতা ৫ ফুট ৫ ইঞ্চি, relationship status single এবং জানানো net worth ০ টাকা।',
          private: 'Founder-এর সম্পর্কে অন্য কোনো তথ্য দেওয়ার অধিকার আমার নেই।',
        }
      : {
          founder: 'The founder of Dristhty Apps is Imran Ahmad.',
          education: 'Imran Ahmad studies Computer Science and Engineering (CSE) at Gono Bishwabidyalay.',
          location: 'Imran Ahmad lives in Savar.',
          height: 'Imran Ahmad is 5 feet 5 inches tall.',
          relationship: 'Imran Ahmad’s relationship status is single.',
          netWorth: 'Imran Ahmad’s stated net worth is 0 BDT.',
          profile: 'Imran Ahmad studies Computer Science and Engineering (CSE) at Gono Bishwabidyalay, lives in Savar, is 5 feet 5 inches tall, is single, and has stated a net worth of 0 BDT.',
          private: 'I do not have the right to share any other information about the founder.',
        };

  if (/who\s+(is|was)\s+the\s+founder\s+of\s+(drishti|dristhty\s+apps)\??/.test(latestUserMessage) || /প্রতিষ্ঠাতা.*কে|কে.*প্রতিষ্ঠাতা/.test(message)) return responses.founder;
  if (/qualification|education|study|studies|university|college|পড়াশোনা|পড়াশোনা|বিশ্ববিদ্যাল|যোগ্যতা/.test(latestUserMessage)) return responses.education;
  if (/where.*(live|stay)|location|lives|থাকে|থাকেন|কোথায়.*থাকে|কোথায়.*থাকে/.test(latestUserMessage)) return responses.location;
  if (/height|tall|উচ্চতা|লম্বা/.test(latestUserMessage)) return responses.height;
  if (/relationship|marital|single|বিয়ে|বিয়ে|সম্পর্ক/.test(latestUserMessage)) return responses.relationship;
  if (/net worth|worth|income|সম্পদ|নেট.*ওয়ার্থ|নেট.*ওয়ার্থ/.test(latestUserMessage)) return responses.netWorth;
  if (/(about.*(imran|founder)|imran.*about|founder.*profile|imran.*কে|প্রতিষ্ঠাতা.*সম্পর্কে|ইমরান.*সম্পর্কে)/.test(latestUserMessage)) return responses.profile;
  if (/(imran|founder|প্রতিষ্ঠাতা|ইমরান)/.test(latestUserMessage)) return responses.private;
  return null;
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
