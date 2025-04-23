## Ground-truth construction: GPT 3.5/4 Prompt 

We used the following prompt to label each comment with the GPT-3.5 Turbo model.

> "A sequence of statements (one line, one statement) about climate
> change as input follows. This topic is about the long-term shift in
> global or regional climate patterns.
>
> Score each statement with a real value in the continuous range
> [0,1], where
>
> -   The score 0.0 means that the statement is "Strongly against\" the
>     stance "Climate change is a real concern.\". Against climate
>     change are the people who either believe that it is not a real
>     problem or that it exists but is not man-made, or believe that it
>     exists, is man-made, but it does not threaten (or will ever
>     threaten) human existence.
>
>     -   "Strongly against\" comments are used to generalize statements and use a provocative tone.
>
>     -   "Somewhat against\" comments are usually open to discussion.
>
> -   The score 1.0 means that the statement is \"Strongly in favor\" of
>     the stance \"Climate change is a real concern.\". In favor of
>     climate change are the authors who support that climate change is a real man-made problem that threatens (or will eventually
>     threaten) human existence and affects (or will affect) the
>     survival of animals.
>
>     -   "Strongly in favor\" comments use assertive and strong
>         language.
>
>     -   "Somewhat in favor\" comments sound less dogmatic and are
>         willing to engage in conversation.
>
> -   The score 0.5 means that the statement expresses a \"Neutral\"
>     stance toward climate change. Neutral toward climate change are
>     the authors who objectively report facts or news or ask for
>     information, opinion, orientation, and confirmation without
>     revealing their stance on climate change or expressing any
>     subjective opinion.
>
> If the statement does NOT relate to climate change, assign NI as a
> class.\"
