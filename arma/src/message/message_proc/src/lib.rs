use darling::{
    ast::{self},
    FromDeriveInput, FromField, FromVariant,
};
use proc_macro::TokenStream;
use proc_macro2::{Ident, TokenStream as TokenStream2};
use quote::{quote, ToTokens};
use syn::DeriveInput;

#[proc_macro_derive(Arma, attributes(arma))]
/// Creates the to_arma function based on the attributes for this struct
pub fn derive_arma_struct(input: TokenStream) -> TokenStream {
    let input = syn::parse_macro_input!(input as DeriveInput);

    let derived_input = ArmaReceiver::from_derive_input(&input).unwrap();
    quote! { #derived_input }.into()
}

#[derive(Debug, FromDeriveInput)]
#[darling(attributes(arma))]
struct ArmaReceiver {
    ident: syn::Ident,
    data: ast::Data<ArmaVariantReceiver, ArmaFieldReceiver>,
}

#[derive(Debug, FromVariant)]
#[darling(attributes(arma))]
struct ArmaVariantReceiver {
    ident: syn::Ident,
    fields: ast::Fields<ArmaFieldReceiver>,

    #[darling(default)]
    function: String,
}

#[derive(Debug, FromField)]
#[darling(attributes(arma))]
struct ArmaFieldReceiver {
    ident: Option<syn::Ident>,
}

impl ToTokens for ArmaReceiver {
    fn to_tokens(&self, tokens: &mut TokenStream2) {
        let ArmaReceiver {
            ref ident,
            ref data,
        } = *self;

        let data = data.as_ref();
        match data {
            ast::Data::Enum(variant) => arma_enum(ident, tokens, &variant),
            ast::Data::Struct(s) => arma_struct(ident, tokens, &s.fields),
        };
    }
}

fn arma_enum(ident: &Ident, tokens: &mut TokenStream2, variant: &Vec<&ArmaVariantReceiver>) {
    // One set for IntoArma: Data::Add(a) => a.to_arma()
    // Only matters for variants with value
    let into_arma = variant
        .iter()
        .filter_map(|v| {
            if v.fields.is_empty() {
                return None;
            }

            let variant = &v.ident;

            Some(quote! {
                #ident::#variant(ref o) => o.to_arma()
            })
        })
        .collect::<Vec<_>>();

    let sqf_functions = variant
        .iter()
        .filter_map(|v| {
            if v.function.is_empty() {
                return None;
            }

            let variant = &v.ident;
            let function = &v.function;

            Some(quote! {
                #ident::#variant(_) => #function
            })
        })
        .collect::<Vec<_>>();

    tokens.extend(quote! {
        impl IntoArma for #ident {
            fn to_arma(&self) -> ArmaValue {
                match self {
                    #(#into_arma,)*
                    _ => ArmaValue::Null,
                }
            }
        }

        impl #ident {
            pub fn sqf_function(&self) -> &str {
                match self {
                    #(#sqf_functions,)*
                    _ => "",
                }
            }
        }
    });
}

fn arma_struct(ident: &Ident, tokens: &mut TokenStream2, fields: &Vec<&ArmaFieldReceiver>) {
    let arguments = fields
        .iter()
        .enumerate()
        .filter_map(|(_i, field)| {
            if field.ident.is_none() {
                return None;
            }

            Some(field.ident.as_ref().unwrap().to_owned())
        })
        .collect::<Vec<_>>();

    tokens.extend(quote! {
        impl arma_rs::IntoArma for #ident {
            fn to_arma(&self) -> arma_rs::Value {
                let mut vec: Vec<Vec<arma_rs::Value>> = Vec::new();

                #(
                    vec.push(vec![stringify!(#arguments).to_arma(), self.#arguments.to_arma()]);
                )*

                vec.to_arma()
            }
        }
    });
}
