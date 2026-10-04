export function toSupportRequestPayload({fullName,email,phone,subject,message,userId=null}){
  return {
    user_id:userId,
    customer_name:fullName.trim(),
    customer_email:email.trim(),
    customer_phone:phone.trim(),
    subject:subject.trim(),
    message:message.trim(),
    status:'new',
  };
}